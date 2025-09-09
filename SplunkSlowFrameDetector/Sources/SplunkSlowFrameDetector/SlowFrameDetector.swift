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
import SplunkCommon
#if os(iOS) || os(tvOS) || os(visionOS)
import UIKit
#endif

// MARK: - SlowFrameDetector

/// Detects and reports slow and frozen frames in the user interface.
///
/// This class monitors the application's frame rate using `CADisplayLink`. It identifies "slow frames"
/// when the time between frames exceeds the expected duration plus a (percentage) tolerance. It also
/// detects "frozen frames" when the main thread is unresponsive for a significant period.
///
/// These events are reported as metrics to the configured destination.
public final class SlowFrameDetector {

    /// The percentage of the frame's expected duration that is added as a tolerance when detecting slow frames.
    ///
    /// A frame is considered "slow" if its actual duration exceeds the expected duration (e.g., 16.67ms
    /// for 60Hz) plus this tolerance percentage. The default value is `15.0`.
    public static let slowFrameTolerancePercentage: Double = 15.0

    /// The time interval, in seconds, after which a frame is considered "frozen."
    ///
    /// If the main thread does not process frames for a period longer than this threshold, a frozen frame
    /// is reported. The default value is `0.7` seconds.
    public static let frozenFrameThreshold: TimeInterval = 0.7

    /// The current state of the `SlowFrameDetector`.
    ///
    /// This object provides information about the detector's status, such as whether it is currently enabled.
    public let state = SlowFrameDetectorState()

    /// The remote configuration for the `SlowFrameDetector`.
    ///
    /// This property can be used to update the detector's behavior based on settings fetched from a remote source.
    public var configuration: SlowFrameDetectorRemoteConfiguration?
    private let logic: SlowFrameLogic
    private var ticker: SlowFrameTicker?

    init(
        ticker: SlowFrameTicker?,
        destinationFactory: @escaping () -> SlowFrameDetectorDestination
    ) {
        self.ticker = ticker
        logic = SlowFrameLogic(destinationFactory: destinationFactory)
    }

    #if os(iOS) || os(tvOS) || os(visionOS)
    /// Initializes a new instance of the `SlowFrameDetector`.
    ///
    /// This convenience initializer sets up the detector with default dependencies, including a
    /// `DisplayLinkTicker` for frame monitoring and an `OTelDestination` for reporting.
    public required convenience init() {
        self.init(ticker: DisplayLinkTicker(), destinationFactory: { OTelDestination() })
    }
    #else
    // nil ticker for unsupported platforms
    public required init() {
        self.init(ticker: nil, destinationFactory: { OTelDestination() })
    }
    #endif

    deinit {
        #if os(iOS) || os(tvOS) || os(visionOS)
        NotificationCenter.default.removeObserver(self)
        #endif
        ticker?.stop()

        // We need a strong reference to the actor because self is going away
        let logicToStop = self.logic

        // deinit does not need to wait for this so we wrap it in a task
        Task {
            await logicToStop.stop()
        }
    }

    /// Installs and configures the slow frame detector.
    ///
    /// This method should be called as part of the module initialization process. It enables or disables
    /// the detector based on the provided local configuration.
    /// - Parameters:
    ///   - configuration: The local configuration for the module, which determines if the feature is enabled.
    ///   - remoteConfiguration: The remote configuration for the module.
    public func install(
        with configuration: (any ModuleConfiguration)?,
        remoteConfiguration: (any RemoteModuleConfiguration)?
    ) {
        let localConfig = configuration as? SlowFrameDetectorConfiguration
        state.isEnabled = localConfig?.isEnabled ?? true
        if state.isEnabled {
            start()
        }
    }

    /// Starts the slow and frozen frame detection process.
    ///
    /// This method sets up the frame ticker and registers for application lifecycle notifications to
    /// automatically pause and resume monitoring.
    public func start() {
        guard ticker != nil else {
            return
        }

        Task { [weak self] in
            guard let self = self else { return }

            let started = await self.logic.start()
            guard started else { return }

            self.ticker?.onFrame = { [weak self] timestamp, duration in
                guard let self = self else { return }
                Task { await self.logic.handleFrame(timestamp: timestamp, duration: duration) }
            }

            #if os(iOS) || os(tvOS) || os(visionOS)
            let nc = NotificationCenter.default
            nc.addObserver(self, selector: #selector(self.appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
            nc.addObserver(self, selector: #selector(self.appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
            nc.addObserver(self, selector: #selector(self.appWillTerminate), name: UIApplication.willTerminateNotification, object: nil)
            #endif

            self.ticker?.start()
        }
    }

    /// Stops the slow and frozen frame detection process.
    ///
    /// This method invalidates the frame ticker, removes notification observers, and flushes any buffered data.
    public func stop() async {
        #if os(iOS) || os(tvOS) || os(visionOS)
        NotificationCenter.default.removeObserver(self)
        #endif
        ticker?.stop()
        await logic.stop()
    }

    #if os(iOS) || os(tvOS) || os(visionOS)
    @objc private func appWillResignActive(_ note: Notification) {
        ticker?.pause()
        Task { await logic.appWillResignActive() }
    }

    @objc private func appDidBecomeActive(_ note: Notification) {
        ticker?.resume()
        Task { await logic.appDidBecomeActive() }
    }

    @objc private func appWillTerminate(_ note: Notification) {
        Task { await logic.appWillTerminate() }
    }
    #endif

    func flushBuffers() async {
        await logic.flushBuffers()
    }
}
