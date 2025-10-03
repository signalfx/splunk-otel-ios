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

/// Detects and reports slow and frozen frames in the user interface.
///
/// This class monitors the application's frame rate using `CADisplayLink`. It identifies "slow frames"
/// when the time between frames exceeds the expected duration plus a (percentage) tolerance. It also
/// detects "frozen frames" when the main thread is unresponsive for a significant period.
///
/// These events are reported as metrics to the configured destination.
public final class SlowFrameDetector: NSObject {

    // MARK: - Public Properties

    /// The current state of the `SlowFrameDetector`.
    ///
    /// This object provides information about the detector's status, such as whether it is currently enabled.
    public let state = SlowFrameDetectorState()

    /// The remote configuration for the `SlowFrameDetector`.
    ///
    /// This property can be used to update the detector's behavior based on settings fetched from a remote source.
    public var configuration: SlowFrameDetectorRemoteConfiguration?

    // MARK: - Internal Constants

    /// The percentage by which a frame's duration must exceed the expected duration to trigger a slow frame report.
    static let slowFrameTolerancePercentage: Double = 15.0

    /// The duration of main thread unresponsiveness that triggers a frozen frame report.
    static let frozenFrameThreshold: TimeInterval = 0.7

    // MARK: - Private Properties

    private let logic: SlowFrameLogic
    private var ticker: (any SlowFrameTicker)?
    private var detectorTask: Task<Void, Never>?

    #if os(iOS) || os(tvOS) || os(visionOS)
    /// A helper encapsulating lifecycle observers.
    private lazy var lifecycleObserver = LifecycleObserver(observer: self)
    #endif

    // MARK: - Test-only Properties

    #if DEBUG
    var logicForTest: SlowFrameLogic { logic }
    #endif

    // MARK: - Initialization

    init(
        ticker: (any SlowFrameTicker)?,
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
    override public required convenience init() {
        self.init(ticker: DisplayLinkTicker(), destinationFactory: { OTelDestination() })
    }
    #else
    /// Initializes a new instance of the `SlowFrameDetector` for unsupported platforms.
    public required convenience init() {
        // nil ticker for unsupported platforms
        self.init(ticker: nil, destinationFactory: { OTelDestination() })
    }
    #endif

    deinit {
        // Cancel the main detector task to ensure all managed resources are cleaned up.
        detectorTask?.cancel()
    }

    // MARK: - Public Methods

    /// Installs and configures the slow frame detector.
    ///
    /// This method should be called as part of the module initialization process. It enables or disables
    /// the detector based on the provided local configuration.
    /// - Parameters:
    ///   - configuration: The local configuration for the module, which determines if the feature is enabled.
    ///   - remoteConfiguration: The remote configuration for the module.
    public func install(
        with configuration: (any ModuleConfiguration)?,
        remoteConfiguration _: (any RemoteModuleConfiguration)?
    ) {
        let localConfig = configuration as? SlowFrameDetectorConfiguration
        state.isEnabled = localConfig?.isEnabled ?? true
        if state.isEnabled {
            start()
        }
    }

    // MARK: - Internal Methods

    /// Starts the slow and frozen frame detection process.
    ///
    /// This method sets up the frame ticker and registers for application lifecycle notifications to
    /// automatically pause and resume monitoring. This method is idempotent.
    func start() {
        guard ticker != nil, detectorTask == nil else {
            return
        }

        // This task is the main run loop for the detector.
        detectorTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                try await logic.start()

                ticker?.onFrame = { [weak self] timestamp, duration in
                    guard let self else {
                        return
                    }

                    await logic.handleFrame(timestamp: timestamp, duration: duration)
                }

                // Dispatch UI-related setup to the main actor.
                await MainActor.run {
                    self.lifecycleObserver.add()
                    self.ticker?.start()
                }

                // The task will suspend here indefinitely until it is cancelled.
                try await Task.sleep(nanoseconds: .max)
            }
            catch is CancellationError {
                // Task was cancelled. Dispatch cleanup to the main actor.
                await MainActor.run {
                    self.ticker?.stop()
                    self.lifecycleObserver.remove()
                }
            }
            catch {
                // An error occurred during startup. Dispatch cleanup to the main actor.
                await MainActor.run {
                    self.ticker?.stop()
                    self.lifecycleObserver.remove()
                }
            }
        }
    }

    /// Stops the slow and frozen frame detection process.
    ///
    /// This method invalidates the frame ticker, removes notification observers, and flushes any buffered data.
    func stop() async {
        // Run the two independent cleanup operations concurrently.
        async let detectorTaskCleanup: () = cleanupDetectorTask()
        async let logicCleanup: () = logic.stop()

        // Await both to ensure all cleanup is complete before this method returns.
        _ = await (detectorTaskCleanup, logicCleanup)
    }

    func flushBuffers() async {
        await logic.flushBuffers()
    }

    // MARK: - Private Methods

    /// Cancels and waits for the main detector task to finish its cleanup.
    private func cleanupDetectorTask() async {
        detectorTask?.cancel()
        _ = await detectorTask?.result
        detectorTask = nil
    }

    // MARK: - Lifecycle Handlers

    #if os(iOS) || os(tvOS) || os(visionOS)
    @MainActor
    @objc
    private func appWillResignActive(_: Notification) {
        ticker?.pause()
        Task { await logic.appWillResignActive() }
    }

    @MainActor
    @objc
    private func appDidBecomeActive(_: Notification) {
        ticker?.resume()
        Task { await logic.appDidBecomeActive() }
    }

    @objc
    private func appWillTerminate(_: Notification) {
        Task { await logic.appWillTerminate() }
    }
    #endif
}

// MARK: - Nested Helper Class

#if os(iOS) || os(tvOS) || os(visionOS)
@MainActor
extension SlowFrameDetector {
    /// Encapsulates the state and registration of application lifecycle notification observers.
    private final class LifecycleObserver {
        private weak var observer: NSObject?
        private var isRegistered = false

        /// Declarative notification/selector configuration.
        private let specs: [(name: Notification.Name, selector: Selector)] = [
            (UIApplication.willResignActiveNotification, #selector(SlowFrameDetector.appWillResignActive(_:))),
            (UIApplication.didBecomeActiveNotification, #selector(SlowFrameDetector.appDidBecomeActive(_:))),
            (UIApplication.willTerminateNotification, #selector(SlowFrameDetector.appWillTerminate(_:)))
        ]

        init(observer: NSObject) {
            self.observer = observer
        }

        func add() {
            guard let observer, !isRegistered else {
                return
            }

            let notificationCenter = NotificationCenter.default
            for spec in specs {
                notificationCenter.addObserver(observer, selector: spec.selector, name: spec.name, object: nil)
            }
            isRegistered = true
        }

        func remove() {
            guard let observer, isRegistered else {
                return
            }

            let notificationCenter = NotificationCenter.default
            for spec in specs {
                notificationCenter.removeObserver(observer, name: spec.name, object: nil)
            }
            isRegistered = false
        }
    }
}
#endif
