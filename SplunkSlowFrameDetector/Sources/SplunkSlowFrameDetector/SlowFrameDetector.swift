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

    /// Indicates whether the slow frame detection feature is currently enabled.
    ///
    /// The default value is `false`.
    public private(set) var isEnabled = false

    // MARK: - Internal Constants

    /// The percentage by which a frame's duration must exceed the expected duration to trigger a slow frame report.
    static let slowFrameTolerancePercentage: Double = 15.0

    /// The duration of main thread unresponsiveness that triggers a frozen frame report.
    static let frozenFrameThreshold: TimeInterval = 0.7

    // MARK: - Private Properties

    private let logic: SlowFrameLogic
    private var ticker: (any SlowFrameTicker)?
    private var detectorTask: Task<Void, Never>?
    private var appStateObserverTask: Task<Void, Never>?

    #if os(iOS) || os(tvOS) || os(visionOS)
        /// A helper encapsulating lifecycle observers.
        private lazy var lifecycleObserver = LifecycleObserver()
    #endif

    // MARK: - Test-only Properties

    #if DEBUG
        var logicForTest: SlowFrameLogic { logic }

        /// A test-only method to bypass the `AsyncStream` and process a frame directly and deterministically.
        func handleFrameForTest(timestamp: TimeInterval, duration: TimeInterval) async {
            await logic.handleFrame(timestamp: timestamp, duration: duration)
        }
    #endif


    // MARK: - Initialization

    init(
        ticker: (any SlowFrameTicker)?,
        destination: SlowFrameDetectorDestination
    ) {
        self.ticker = ticker
        logic = SlowFrameLogic(destination: destination)
    }

    #if os(iOS) || os(tvOS) || os(visionOS)
        /// Initializes a new instance of the `SlowFrameDetector`.
        ///
        /// This convenience initializer sets up the detector with default dependencies, including a
        /// `DisplayLinkTicker` for frame monitoring and an `OTelDestination` for reporting.
        override public required convenience init() {
            self.init(ticker: DisplayLinkTicker(), destination: OTelDestination())
        }
    #else
        /// Initializes a new instance of the `SlowFrameDetector` for unsupported platforms.
        public required convenience init() {
            // nil ticker for unsupported platforms
            self.init(ticker: nil, destination: OTelDestination())
        }
    #endif

    deinit {
        // Cancel the main detector task to ensure all managed resources are cleaned up.
        detectorTask?.cancel()
        appStateObserverTask?.cancel()
    }


    // MARK: - Public Methods

    /// Installs and configures the slow frame detector.
    ///
    /// This method should be called as part of the module initialization process. It enables or disables
    /// the detector based on the provided local configuration.
    ///
    /// - Parameters:
    ///   - configuration: Module specific local configuration.
    ///   - remoteConfiguration: Module specific remote configuration.
    public func install(
        with configuration: (any ModuleConfiguration)?,
        remoteConfiguration _: (any RemoteModuleConfiguration)?
    ) {
        let localConfig = configuration as? SlowFrameDetectorConfiguration
        isEnabled = localConfig?.isEnabled ?? true
        if isEnabled {
            start()
        }
    }


    // MARK: - Internal Methods

    /// Starts the slow and frozen frame detection process.
    ///
    /// This method sets up the frame ticker and registers for application lifecycle notifications to
    /// automatically pause and resume monitoring. This method is idempotent.
    func start() {
        guard let ticker, detectorTask == nil else {
            return
        }

        #if os(iOS) || os(tvOS) || os(visionOS)
            startObservingAppState()
        #endif

        // This task is the main run loop for the detector
        detectorTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                try await logic.start()

                // Dispatch UI-related setup to the main actor
                await MainActor.run {
                    #if os(iOS) || os(tvOS) || os(visionOS)
                        self.lifecycleObserver.add()
                    #endif
                    self.ticker?.start()
                }

                for await (timestamp, duration) in ticker.onFrameStream {
                    await logic.handleFrame(timestamp: timestamp, duration: duration)
                }
            }
            catch {
                // Task was cancelled or an error occurred.
                await cleanupAfterTaskError()
            }
        }
    }

    /// Stops the slow and frozen frame detection process.
    ///
    /// This method invalidates the frame ticker, removes notification observers, and flushes any buffered data.
    func stop() async {
        cancelAppStateObserver()

        // Run the two independent cleanup operations concurrently.
        async let detectorTaskCleanup: () = cleanupDetectorTask()
        async let logicCleanup: () = logic.stop()

        await stopTickerAndObservers()

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

    private func cleanupAfterTaskError() async {
        await MainActor.run {
            self.ticker?.stop()
            #if os(iOS) || os(tvOS) || os(visionOS)
                self.lifecycleObserver.remove()
            #endif
        }
    }

    #if os(iOS) || os(tvOS) || os(visionOS)
        private func startObservingAppState() {
            appStateObserverTask?.cancel()
            appStateObserverTask = Task { [weak self] in
                guard let self else {
                    return
                }

                for await notification in lifecycleObserver.stream {
                    switch notification {
                    case .appWillResignActive:
                        await ticker?.pause()
                        await logic.appWillResignActive()

                    case .appDidBecomeActive:
                        await ticker?.resume()
                        await logic.appDidBecomeActive()

                    case .appWillTerminate:
                        await logic.appWillTerminate()
                    }
                }
            }
        }
    #endif

    private func cancelAppStateObserver() {
        appStateObserverTask?.cancel()
        appStateObserverTask = nil
    }

    private func stopTickerAndObservers() async {
        await MainActor.run {
            ticker?.stop()
            #if os(iOS) || os(tvOS) || os(visionOS)
                lifecycleObserver.remove()
            #endif
        }
    }
}

// MARK: - Nested Helper Class

#if os(iOS) || os(tvOS) || os(visionOS)
    @MainActor
    extension SlowFrameDetector {
        enum LifecycleEvents {
            case appWillResignActive
            case appDidBecomeActive
            case appWillTerminate
        }

        /// Encapsulates the state and registration of application lifecycle notification observers.
        private final class LifecycleObserver: NSObject {
            private var isRegistered = false
            private var continuation: AsyncStream<LifecycleEvents>.Continuation?

            var stream: AsyncStream<LifecycleEvents> {
                AsyncStream { self.continuation = $0 }
            }

            /// Declarative notification/selector configuration.
            private let specs: [(name: Notification.Name, selector: Selector)] = [
                (UIApplication.willResignActiveNotification, #selector(appWillResignActive(_:))),
                (UIApplication.didBecomeActiveNotification, #selector(appDidBecomeActive(_:))),
                (UIApplication.willTerminateNotification, #selector(appWillTerminate(_:)))
            ]

            deinit {
                remove()
                continuation?.finish()
            }

            func add() {
                guard !isRegistered else {
                    return
                }

                let notificationCenter = NotificationCenter.default
                for spec in specs {
                    notificationCenter.addObserver(self, selector: spec.selector, name: spec.name, object: nil)
                }
                isRegistered = true
            }

            func remove() {
                guard isRegistered else {
                    return
                }

                let notificationCenter = NotificationCenter.default
                for spec in specs {
                    notificationCenter.removeObserver(self, name: spec.name, object: nil)
                }
                isRegistered = false
            }

            @objc
            private func appWillResignActive(_: Notification) {
                continuation?.yield(.appWillResignActive)
            }

            @objc
            private func appDidBecomeActive(_: Notification) {
                continuation?.yield(.appDidBecomeActive)
            }

            @objc
            private func appWillTerminate(_: Notification) {
                continuation?.yield(.appWillTerminate)
            }
        }
    }
#endif
