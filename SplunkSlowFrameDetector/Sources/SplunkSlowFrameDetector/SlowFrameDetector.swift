/*
Copyright 2021 Splunk Inc.

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


/*
Adapted from SlowFrameDetector implementation at https://github.com/signalfx/splunk-otel-ios
 */


import Foundation
import SplunkSharedProtocols
import QuartzCore
import UIKit


public final class SlowFrameDetector {

    typealias FrameBuffer = [String: Int]

    actor ReportableFramesBuffer {
        private var buffer: FrameBuffer = [:]

        func incrementFrames(_ screenName: String) async {
            buffer[screenName, default: 0] += 1
        }

        func framesToReport() async -> FrameBuffer {
            let bufferCopy = buffer
            buffer.removeAll()
            return bufferCopy
        }
    }

    private var timer: Timer? = Timer()
    private var displayLink: CADisplayLink?
    private var displayLinkTask: Task<Void, Never>? // for async/await

    private var slowFrames: ReportableFramesBuffer? = ReportableFramesBuffer()
    private var frozenFrames: ReportableFramesBuffer? = ReportableFramesBuffer()

    private var previousTimestamp: CFTimeInterval = 0.0
    private var currentScreenName = getScreenName()

    private var config: SlowFrameDetectorRemoteConfiguration?

    // Legacy settings which are ignored (see comments in displayLinkCallback)
    private var slowThresholdSeconds: CFTimeInterval = 16.7
    private var frozenThresholdSeconds: CFTimeInterval = 700.0

    // Candidates to replace threshold values in the future
    private var tolerancePercentage: Double = 15.0
    private var frozenDurationMultipler: Double = 40.0



    // MARK: - SlowFrameDetector lifecycle

    public required init() {} // For Module conformance

    deinit {
        stop()
    }

    public func install(with configuration: (any ModuleConfiguration)?, remoteConfiguration: (any RemoteModuleConfiguration)?) {

        config = remoteConfiguration as? SlowFrameDetectorRemoteConfiguration
        let sfd = SlowFrameDetector()
        if let config {
            slowThresholdSeconds = config.slowFrameThresholdMilliseconds / 1e3
            frozenThresholdSeconds = config.frozenFrameThresholdMilliseconds / 1e3
        }
        sfd.start()
    }

    public func start() {

        // If we already have a displayLink instance, start must have already been called.
        if displayLink != nil {
            return
        }


        // Stay informed when screen name is updated by code elsewhere
        addScreenNameChangeCallback { [weak self] name in
            self?.currentScreenName = name
        }


        // Stay on top of app lifecycle so we can pause things if needed
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive(notification:)), name: UIApplication.willResignActiveNotification, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive(notification:)), name: UIApplication.didBecomeActiveNotification, object: nil)


        // Runs every frame to detect if any frame took longer than expected
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkCallback))
        displayLink?.add(to: .main, forMode: .common)


        // Timer for flushing frames
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task {
                await self?.dumpFrames()
            }
        }
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        displayLink?.invalidate()
        displayLink = nil
        displayLinkTask?.cancel()
        displayLinkTask = nil
        slowFrames = nil
        frozenFrames = nil
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
    }


    // MARK: - App lifecycle events we hook into

    @objc func appWillResignActive(notification: Notification) {
        displayLink?.isPaused = true
        Task { [weak self] in
            await self?.dumpFrames()
        }
    }

    @objc func appDidBecomeActive(notification: Notification) {
        previousTimestamp = 0.0
        displayLink?.isPaused = false
    }


    // MARK: - CADisplayLink callback, check is here

    @objc func displayLinkCallback(_ displayLink: CADisplayLink) {

        // TODO: Verify the following understanding
        //
        // We are working off of some ambiguous documentation from Apple.
        // https://developer.apple.com/documentation/quartzcore/cadisplaylink
        //
        // On the one hand, they say:
        //   You calculate the expected amount of time your app has to render
        //   each frame by using targetTimestamp-timestamp
        //
        // On the other hand, they also say:
        //   To calculate the actual frame duration, use targetTimestamp-timestamp
        //
        // Notice the two calculations they show are the same. It seems in the
        // second excerpt they are using a special meaning of "actual frame
        // duration" which means "actual expected frame duration under the
        // system's current (actual) frame rate" The word "actual" being added
        // because they are cognizant that their frame rate varies, with the
        // current value the system has chosen being the "actual" rate -- as
        // distinct from the "actual empirically observed" rate, a different
        // concept entirely, which I believe would be most people's reasonable
        // quick (and mistaken) interpretation of the second passage.
        //
        // The current implementation of this function relies on the
        // understanding that the first of their two passages quoted above
        // resolves the ambiguity: they mean the /expected/ duration is what
        // results from the calculation they show.

        let actualTimestamp = displayLink.timestamp
        let targetTimestamp = displayLink.targetTimestamp

        if previousTimestamp == 0.0 {
            previousTimestamp = actualTimestamp
            return
        }

        // TODO: This approach will need PM approval, because it totally ignores the incoming settings from the configuration. We could map the settings or there are a number of approaches for us to talk about but I think this is the right one. Ignoring the settings is simplest and fits with the fact that the platform is giving us a different picture to deal with, with variable FPS being common.

        // Set the previousTimestamp before any potential short circuit
        let actualDuration = actualTimestamp - previousTimestamp
        previousTimestamp = actualTimestamp

        // Short circuit if we already have a Task underway, so they don't pile up
        guard displayLinkTask == nil else { return }

        // Set up the expectation
        let expectedDuration = targetTimestamp - actualTimestamp

        // `tolerancePercentage` percent of the expected duration, used for slow frames
        let tolerance = expectedDuration * tolerancePercentage

        // Duration is too long... slow frame
        let isSlow = actualDuration > expectedDuration + tolerance

        // Frozen is much longer duration than simply "slow"
        let isFrozen = actualDuration > expectedDuration * frozenDurationMultipler

        // Apply isFrozen check first because it's a subset of isSlow
        if isFrozen {
            displayLinkTask = Task { [weak self] in
                await self?.frozenFrames?.incrementFrames(self?.currentScreenName ?? "Unknown")
                self?.displayLinkTask = nil
            }
        } else if isSlow {
            displayLinkTask = Task { [weak self] in
                await self?.slowFrames?.incrementFrames(self?.currentScreenName ?? "Unknown")
                self?.displayLinkTask = nil
            }
        }
     }


    // MARK: - Reporting

    private func dumpFrames() async {

        if let slowReportable = await slowFrames?.framesToReport() {
            for (screenName, count) in slowReportable {
                reportFrame("slowRenders", screenName, count)
            }
        }

        if let frozenReportable = await frozenFrames?.framesToReport() {
            for (screenName, count) in frozenReportable {
                reportFrame("frozenRenders", screenName, count)
            }
        }
    }

    private func reportFrame(_ type: String, _ screenName: String, _ count: Int) {

        // TODO: DEMRUM-12 - iOS Spike: Integrate COP agent with Splunk O11y

        // The commented-out code below is from the SignalFX repo implementation.
        // We need to connect with the corresponding code in our COP implementation
        // such that exports will work and data will show up on the server.

        // let tracer = buildTracer()
        // let now = Date()
        // let span = tracer.spanBuilder(spanName: type).setStartTime(time: now).startSpan()
        // span.setAttribute(key: Constants.AttributeNames.COMPONENT, value: "ui")
        // span.setAttribute(key: Constants.AttributeNames.COUNT, value: count)
        // span.setAttribute(key: Constants.AttributeNames.SCREEN_NAME, value: screenName)
        // span.end(time: now)
    }
}
