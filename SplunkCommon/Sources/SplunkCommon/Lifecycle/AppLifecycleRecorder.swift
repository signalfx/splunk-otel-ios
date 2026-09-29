//
/*
Copyright 2026 Splunk Inc.

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

#if canImport(UIKit)
    import UIKit
#endif

/// Records process lifecycle evidence for the agent core.
///
/// The recorder is shared by AppStart, AppState, and hybrid integrations. Initial
/// lifecycle fields use first-event-wins semantics, while a bounded ordered event
/// history preserves evidence for SDKs installed after the process lifecycle began.
@_spi(SplunkInternal)
public final class AppLifecycleRecorder {


    struct Observer {
        let callback: (Update) -> Void
        var initialSnapshotDelivered: Bool
    }

    // MARK: - Private properties

    let notificationCenter: NotificationCenter
    let lock = NSLock()
    let backgroundLaunchThreshold: TimeInterval = 10.0
    let maxHistoryCount = 128
    let recorderStartedAt: Date
    let prewarmDetected: Bool

    var notificationTokens: [NSObjectProtocol] = []
    var observers: [UUID: Observer] = [:]

    var launchOrigin: LaunchOrigin = .unknown
    var launchOriginConfidence: LaunchOriginConfidence = .unknown
    var didFinishLaunchingTimestamp: Date?
    var willEnterForegroundTimestamp: Date?
    var didBecomeActiveTimestamp: Date?
    var eventHistory: [EventRecord] = []
    var nextSequence: UInt64 = 0

    // MARK: - Initialization

    /// Creates and starts a lifecycle recorder.
    @_spi(SplunkInternal)
    public convenience init(notificationCenter: NotificationCenter = .default, enabled: Bool = true) {
        self.init(
            notificationCenter: notificationCenter,
            enabled: enabled,
            captureInitialApplicationState: false
        )
    }

    /// Returns the process-wide recorder intended for early adapter bootstrap.
    ///
    /// Integrations that can load before `UIApplication` lifecycle notifications
    /// should call this from their earliest native entry point. Later SDK install
    /// reuses the same recorder and receives the already captured history.
    @_spi(SplunkInternal)
    public static func bootstrap() -> AppLifecycleRecorder {
        bootstrappedRecorder
    }

    private static let bootstrappedRecorder = AppLifecycleRecorder(
        notificationCenter: .default,
        enabled: true,
        captureInitialApplicationState: false
    )

    private init(
        notificationCenter: NotificationCenter,
        enabled: Bool,
        captureInitialApplicationState: Bool
    ) {
        self.notificationCenter = notificationCenter
        recorderStartedAt = Date()
        prewarmDetected = ProcessInfo.processInfo.environment["ActivePrewarm"] == "1"

        if captureInitialApplicationState {
            captureInitialApplicationStateIfAvailable()
        }

        if enabled {
            start()
        }
    }

    deinit {
        stop()
    }

    // MARK: - Public

    /// Returns the latest first-launch snapshot.
    @_spi(SplunkInternal)
    public func snapshot() -> Snapshot {
        withLock {
            makeSnapshot()
        }
    }

    /// Subscribes to lifecycle updates and receives the current snapshot first.
    @_spi(SplunkInternal)
    @discardableResult
    public func addObserver(_ observer: @escaping (Update) -> Void) -> UUID {
        let identifier = UUID()

        if Thread.isMainThread {
            let snapshot = withLock { () -> Snapshot in
                observers[identifier] = Observer(
                    callback: observer,
                    initialSnapshotDelivered: true
                )
                return makeSnapshot()
            }

            // No main-queue work can interleave between registration and this
            // callback. Deliver outside the lock so the observer may re-enter.
            observer(Update(event: nil, eventRecord: nil, snapshot: snapshot))
        }
        else {
            // Register immediately, but hold live delivery until the main queue
            // can provide a current snapshot. This avoids blocking a hybrid
            // bridge thread while preserving snapshot-before-event ordering.
            _ = withLock {
                observers[identifier] = Observer(
                    callback: observer,
                    initialSnapshotDelivered: false
                )
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                let delivery = withLock { () -> (callback: (Update) -> Void, snapshot: Snapshot)? in
                    guard var observer = self.observers[identifier] else {
                        return nil
                    }

                    let snapshot = self.makeSnapshot()
                    observer.initialSnapshotDelivered = true
                    self.observers[identifier] = observer
                    return (observer.callback, snapshot)
                }

                guard let delivery else {
                    return
                }

                delivery.callback(
                    Update(event: nil, eventRecord: nil, snapshot: delivery.snapshot)
                )
            }
        }

        return identifier
    }

    /// Removes a lifecycle subscriber.
    @_spi(SplunkInternal)
    public func removeObserver(_ identifier: UUID) {
        _ = withLock {
            observers.removeValue(forKey: identifier)
        }
    }
}
