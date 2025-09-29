//
/*
Copyright 2025 Splunk Inc.

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
import QuartzCore
import SplunkCommon
import UIKit

public final class SlowFrameDetector {

    // MARK: - Nested Types

    typealias FrameBuffer = [String: Int]

    actor ReportableFramesBuffer {
        private var buffer: FrameBuffer = [:]

        func incrementFrames() async {
            buffer["shared", default: 0] += 1
        }

        func framesToReport() async -> FrameBuffer {
            let bufferCopy = buffer
            buffer.removeAll()
            return bufferCopy
        }
    }

    // MARK: - Public Properties

    /// An object that reflects the current state for the module, just `isEnabled` in our case.
    public let state = SlowFrameDetectorState()

    /// The configuration received from a remote source.
    public var configuration: SlowFrameDetectorRemoteConfiguration?

    // MARK: - Private Properties

    /* Frame Detection Machinery */
    private var displayLink: CADisplayLink?
    private var timer: Timer?
    private var displayLinkTask: Task<Void, Never>?

    /* Frame Buffers */
    private var slowFrames = ReportableFramesBuffer()
    private var frozenFrames = ReportableFramesBuffer()

    /// Calculation State.
    private var previousTimestamp: CFTimeInterval = 0.0

    /* Tuning Parameters */
    private var tolerancePercentage: Double = 15.0
    private var frozenDurationMultiplier: Double = 40.0

    // MARK: - Lifecycle

    public required init() {}

    deinit {
        stop()
    }

    public func install(with configuration: (any ModuleConfiguration)?, remoteConfiguration _: (any RemoteModuleConfiguration)?) {

        // Ignore `remoteConfiguration` because when it eventually comes into
        // play, DefaultModulesManager will be using it if needed to veto the
        // installation before we ever get here.
        let localConfiguration = configuration as? SlowFrameDetectorConfiguration

        // If localConfiguration is nil, default to true.
        state.isEnabled = localConfiguration?.isEnabled ?? true

        if state.isEnabled {
            start()
        }
    }

    public func start() {

        // If we already have a displayLink instance, start must have already been called.
        if displayLink != nil {
            return
        }

        // Stay on top of app lifecycle so we can pause things if needed
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(appWillResignActive(notification:)),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )

        center.addObserver(
            self,
            selector: #selector(appDidBecomeActive(notification:)),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )


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
        slowFrames = ReportableFramesBuffer()
        frozenFrames = ReportableFramesBuffer()
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
    }


    // MARK: - App lifecycle events we hook into

    @objc
    func appWillResignActive(notification _: Notification) {
        displayLink?.isPaused = true
        Task { [weak self] in
            await self?.dumpFrames()
        }
    }

    @objc
    func appDidBecomeActive(notification _: Notification) {
        previousTimestamp = 0.0
        displayLink?.isPaused = false
    }


    // MARK: - CADisplayLink callback, check is here

    @objc
    func displayLinkCallback(_ displayLink: CADisplayLink) {

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

        // Set the previousTimestamp before any potential short circuit
        let actualDuration = actualTimestamp - previousTimestamp
        previousTimestamp = actualTimestamp

        // Short circuit if we already have a Task underway, so they don't pile up
        guard displayLinkTask == nil else {
            return
        }

        // Set up the expectation
        let expectedDuration = targetTimestamp - actualTimestamp

        // Tolerance for extra duration above which a frame is considered slow.
        let tolerance = expectedDuration * (tolerancePercentage / 100.0)

        // Duration is too long... slow frame
        let isSlow = actualDuration > expectedDuration + tolerance

        // Frozen is much longer duration than simply "slow"
        let isFrozen = actualDuration > expectedDuration * frozenDurationMultiplier

        // Apply isFrozen check first because it's a subset of isSlow
        if isFrozen {
            displayLinkTask = Task { [weak self] in
                await self?.frozenFrames.incrementFrames()
                self?.displayLinkTask = nil
            }
        }
        else if isSlow {
            displayLinkTask = Task { [weak self] in
                await self?.slowFrames.incrementFrames()
                self?.displayLinkTask = nil
            }
        }
    }


    // MARK: - Reporting

    private func dumpFrames() async {

        let destination = OTelDestination()

        let slowReportable = await slowFrames.framesToReport()
        if !slowReportable.isEmpty {
            for (_, count) in slowReportable {
                destination.send(type: "slowRenders", count: count, sharedState: nil)
            }
        }

        let frozenReportable = await frozenFrames.framesToReport()
        if !frozenReportable.isEmpty {
            for (_, count) in frozenReportable {
                destination.send(type: "frozenRenders", count: count, sharedState: nil)
            }
        }
    }
}
