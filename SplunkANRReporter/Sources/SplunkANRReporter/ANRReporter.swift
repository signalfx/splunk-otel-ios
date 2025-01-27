//
/*
Copyright 2024 Splunk Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

import Foundation
import SplunkSharedProtocols


final public class ANRReporter {


    // MARK: - Private properties

    private let tuning = ANRTunableValues()
    private let detectionQueue = DispatchQueue(label: "com.splunk.rum.anr.background", qos: .background)
    private var config: ANRReporterConfiguration = ANRReporterConfiguration(enabled: true)
    private var isMainThreadResponsive: Bool = false
    private var heartbeatTimer: Timer?
    private var detectionTimer: DispatchSourceTimer?
    private var anrStartTime: DispatchTime?


    // MARK: - ANRReporter lifecycle

    public required init() {} // see install() in Module extension for startup tasks

    func startANRChecking() {
        startHeartbeatInMainThread()
        startDetectionInBackgroundThread()
    }

    func stopANRChecking() {
        detectionTimer?.cancel()
        detectionTimer = nil
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }

    deinit {
        stopANRChecking()
    }


    // MARK: - Timer setup

    /// Schedules a recurring Timer  in the main thread to repeatedly set the `isMainThreadResponsive` flag to true.
    ///
    /// This function kicks off one side of a two-part setup of interacting recurring tasks in different threads.
    ///
    /// In this part of the setup, we have code running in the main thread that does one thing only: it repeatedly sets a shared flag to true.
    ///
    /// The other part of the setup is described in the counterpart function,  `startDetectionInBackgroundThread()`.
    ///
    /// Since we have two different threads writing to a shared flag with no synchronization mechanism, we are living with a race condition here.
    /// For reasons that will be explained in the documentation for `startDetectionInBackgroundThread()`, we accept this race condition as something we can tolerate in our setup.
    ///
    /// The `heartbeatInterval` property of `ANRTunableValues` determines how often the timer updates the flag.
    /// It should be on average more frequent (a lower value, in fractional seconds) than the corresponding `checkInterval`
    /// value used in the detection code so that the main thread can generally stay ahead of the frequency of resets done by the detection code.
    func startHeartbeatInMainThread() {

        DispatchQueue.main.async { [weak self] in

            guard let self else {
                return
            }

            self.heartbeatTimer?.invalidate()

            // The `heartbeatInterval` property of `ANRTunableValue has been chosen empirically and may be 'tuned' upon testing on a variety of devices with different CPU capabilities.
            // The intent is that once we land on a final value that works on the broad spectrum of devices, we will ship with that as a static value.
            let interval = self.tuning.heartbeatInterval

            self.heartbeatTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                guard let self else {
                    return
                }
                // Every `interval` time period we update the flag to be true.
                // The detection code elsewhere in a background queue looks for any failure of this main thread timer to make this update in a timely manner.
                self.isMainThreadResponsive = true
            }
        }
    }

    /// Sets up a block of code to detect ANRs.
    ///
    /// To do this, the code will:
    /// - Keep track of state transitions around main thread responsiveness.
    /// - Time episodes where the main thread appears to be stalled.
    /// - Report on those episodes if they meet the reporting threshold.
    ///
    /// As part of doing its job, the code in this function, to put it in colloquial terms,
    /// "sets up the main thread timer to fail" by repeatedly resetting the shared `isMainThreadResponsive` flag to false.
    /// To be deemed responsive, the main thread must continually "fight back" and set the same flag to true, showing it is still on its game, so to speak.
    /// If an ANR is detected, this code will kick off a report including the duration.
    ///
    /// Race Condition - discussion
    ///
    /// As mentioned above in the comments for `startHeartbeatInMainThread()`, we have a race condition where two different threads are contending to write to the same flag.
    /// We planned for and accept this race condition as a good tradeoff in our situation due to a few factors:
    /// - As a framework vendor have a strong implied requirement that we should not have any undue non-negligible performance impact on our host app.
    /// - This approach is performant (as seen in Xcode performance graph during runs) when compared with an implementation using Swift Atomics.
    /// And we are guessing also compared to an implementation using a serial queue and barrier blocks.
    /// - The cost of failure should be low, because after any initial false reading, the system is overwhelmingly likely to quickly recover. Specifically:
    ///     - False positives will be reduced if not eliminated by the event durations being timed.
    ///     - False negatives will be reduced if not eliminated because once the main thread is stalled, it will no longer update the value.
    ///         (Both of the above two seem sound intuitively, but have also been validated empirically at least on Simulators)
    /// For these reasons we accept the race condition.
    ///
    func startDetectionInBackgroundThread() {

        guard config.enabled else {
            return
        }

        detectionTimer?.cancel()
        detectionTimer = DispatchSource.makeTimerSource(flags: [], queue: detectionQueue)

        // ANR detection logic. Checks whether the heartbeat value is being updated regularly and reports ANR if any delay exceeds the anrConfig.threshold.
        detectionTimer?.setEventHandler { [weak self] in

            guard let self else {
                return
            }

            // This is where we read and then update the shared flag we've been mentioning above.
            let responsive = self.isMainThreadResponsive
            self.isMainThreadResponsive = false

            if responsive {
                if let startTime = self.anrStartTime {
                    // we just recovered from a not-yet-reported ANR
                    let duration = secondsSince(startTime)
                    if duration >= config.threshold {
                        // We'll call this an ANR even though there's a little inaccuracy possible.
                        // Although we are now technically responsive, we *very* recently were not responsive, so it's within reason to consider even an ANR on the edge of over the threshold as valid.
                        // Not to mention that this also catches ANRs that are way over the threshold.
                        self.reportANR(duration: duration)
                    }
                }

                // reset in any case
                self.anrStartTime = nil
            } else {
                // is not responsive
                if let startTime = self.anrStartTime {
                    // a previously detected ANR is still underway
                    let duration = secondsSince(startTime)
                    if duration >= self.tuning.maxANRDuration {
                        // report anr
                        self.reportANR(duration: duration)
                        self.anrStartTime = nil // reset
                    }
                    // don't reset here; if < max, ANR is ongoing
                } else {
                    // new ANR detection
                    self.anrStartTime = DispatchTime.now()
                }
            }
        }

        detectionTimer?.schedule(deadline: .now(), repeating: tuning.checkInterval, leeway: .milliseconds(tuning.checkLeewayMS))
        detectionTimer?.activate()
    }


    // MARK: - ANRReporter helper functions

    private func secondsSince(_ startTime: DispatchTime) -> TimeInterval {
        let durationNanoseconds = DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds
        let durationInSeconds = TimeInterval(durationNanoseconds) / TimeInterval(NSEC_PER_SEC)
        return durationInSeconds
    }


    // MARK: - ANR Reporting

    // This is a placeholder for temporary use only. Will be replaced by
    // real event population and output.
    private func reportANR(duration: Double) {
        print("❌❌ ANR detected. Duration: \(duration) seconds ❌❌\n")
    }

}
