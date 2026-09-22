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

    // MARK: - Public types

    /// The best-known origin of the initial process launch.
    @_spi(SplunkInternal)
    public enum LaunchOrigin: Equatable {
        /// The process was launched for a user-visible foreground activation.
        case foreground

        /// The process was launched to perform background work.
        case background

        /// The launch origin could not be determined reliably.
        case unknown
    }

    /// The lifecycle event kind stored in the ordered history.
    @_spi(SplunkInternal)
    public enum EventKind: Equatable {
        case didFinishLaunching
        case willEnterForeground
        case didBecomeActive
        case willResignActive
        case didEnterBackground
        case willTerminate
    }

    /// The application state observed when a lifecycle event was recorded.
    @_spi(SplunkInternal)
    public enum ApplicationState: Equatable {
        case active
        case inactive
        case background
        case unknown
    }

    /// The source that produced a lifecycle record.
    @_spi(SplunkInternal)
    public enum EventSource: Equatable {
        case notification
    }

    /// A lifecycle event delivered to subscribers.
    @_spi(SplunkInternal)
    public enum Event {
        /// The application finished launching.
        case didFinishLaunching(Date)

        /// The application is moving from background to foreground.
        case willEnterForeground(Date)

        /// The application became active.
        case didBecomeActive(Date)

        /// The application is moving from active to inactive.
        case willResignActive(Date)

        /// The application entered the background.
        case didEnterBackground(Date)

        /// The application is about to terminate.
        case willTerminate(Date)
    }

    /// A timestamped, ordered lifecycle record.
    @_spi(SplunkInternal)
    public struct EventRecord: Equatable {
        public let kind: EventKind
        public let timestamp: Date
        public let applicationState: ApplicationState
        public let sequence: UInt64
        public let source: EventSource

        fileprivate init(
            kind: EventKind,
            timestamp: Date,
            applicationState: ApplicationState,
            sequence: UInt64,
            source: EventSource
        ) {
            self.kind = kind
            self.timestamp = timestamp
            self.applicationState = applicationState
            self.sequence = sequence
            self.source = source
        }

        /// The legacy event representation used by lifecycle consumers.
        public var event: Event {
            switch kind {
            case .didFinishLaunching:
                return .didFinishLaunching(timestamp)

            case .willEnterForeground:
                return .willEnterForeground(timestamp)

            case .didBecomeActive:
                return .didBecomeActive(timestamp)

            case .willResignActive:
                return .willResignActive(timestamp)

            case .didEnterBackground:
                return .didEnterBackground(timestamp)

            case .willTerminate:
                return .willTerminate(timestamp)
            }
        }
    }

    /// The first-launch evidence currently known by the recorder.
    @_spi(SplunkInternal)
    public struct Snapshot {
        /// The time at which this recorder started observing lifecycle events.
        public let recorderStartedAt: Date
        /// Whether the process exposed Apple's prewarm marker to the recorder.
        public let prewarmDetected: Bool
        public let launchOrigin: LaunchOrigin
        public let didFinishLaunching: Date?
        public let willEnterForeground: Date?
        public let didBecomeActive: Date?
        /// Bounded lifecycle history in notification order.
        public let events: [EventRecord]

        fileprivate init(
            recorderStartedAt: Date,
            prewarmDetected: Bool,
            launchOrigin: LaunchOrigin,
            didFinishLaunching: Date?,
            willEnterForeground: Date?,
            didBecomeActive: Date?,
            events: [EventRecord]
        ) {
            self.recorderStartedAt = recorderStartedAt
            self.prewarmDetected = prewarmDetected
            self.launchOrigin = launchOrigin
            self.didFinishLaunching = didFinishLaunching
            self.willEnterForeground = willEnterForeground
            self.didBecomeActive = didBecomeActive
            self.events = events
        }
    }

    /// An update containing the latest snapshot and the event that caused it.
    @_spi(SplunkInternal)
    public struct Update {
        public let event: Event?
        public let eventRecord: EventRecord?
        public let snapshot: Snapshot

        fileprivate init(event: Event?, eventRecord: EventRecord?, snapshot: Snapshot) {
            self.event = event
            self.eventRecord = eventRecord
            self.snapshot = snapshot
        }
    }

    // MARK: - Private properties

    private let notificationCenter: NotificationCenter
    private let lock = NSLock()
    private let backgroundLaunchThreshold: TimeInterval = 10.0
    private let maxHistoryCount = 128
    private let recorderStartedAt: Date
    private let prewarmDetected: Bool

    private var notificationTokens: [NSObjectProtocol] = []
    private var observers: [UUID: (Update) -> Void] = [:]

    private var launchOrigin: LaunchOrigin = .unknown
    private var didFinishLaunchingTimestamp: Date?
    private var willEnterForegroundTimestamp: Date?
    private var didBecomeActiveTimestamp: Date?
    private var eventHistory: [EventRecord] = []
    private var nextSequence: UInt64 = 0

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
        captureInitialApplicationState: true
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
        let snapshot = withLock { () -> Snapshot in
            observers[identifier] = observer
            return makeSnapshot()
        }

        let deliverSnapshot = { [weak self] in
            guard let observer = self?.observer(for: identifier) else {
                return
            }

            observer(Update(event: nil, eventRecord: nil, snapshot: snapshot))
        }

        // Lifecycle consumers are attached on the main thread. Delivering the
        // registration snapshot synchronously there preserves event order when a
        // notification is posted immediately after installation.
        if Thread.isMainThread {
            deliverSnapshot()
        }
        else {
            DispatchQueue.main.async(execute: deliverSnapshot)
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

    // MARK: - Lifecycle observation

    private func start() {
        #if canImport(UIKit)
        guard notificationTokens.isEmpty else {
            return
        }

        let names: [Notification.Name] = [
            UIApplication.didFinishLaunchingNotification,
            UIApplication.willEnterForegroundNotification,
            UIApplication.didBecomeActiveNotification,
            UIApplication.willResignActiveNotification,
            UIApplication.didEnterBackgroundNotification,
            UIApplication.willTerminateNotification
        ]

        for name in names {
            let token = notificationCenter.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.record(notification.name)
            }

            notificationTokens.append(token)
        }
        #endif
    }

    private func stop() {
        for token in notificationTokens {
            notificationCenter.removeObserver(token)
        }

        notificationTokens.removeAll()
    }

    private func record(_ name: Notification.Name) {
        #if canImport(UIKit)
        let timestamp = Date()
        let event: Event
        let kind: EventKind

        switch name {
        case UIApplication.didFinishLaunchingNotification:
            event = .didFinishLaunching(timestamp)
            kind = .didFinishLaunching

        case UIApplication.willEnterForegroundNotification:
            event = .willEnterForeground(timestamp)
            kind = .willEnterForeground

        case UIApplication.didBecomeActiveNotification:
            event = .didBecomeActive(timestamp)
            kind = .didBecomeActive

        case UIApplication.willResignActiveNotification:
            event = .willResignActive(timestamp)
            kind = .willResignActive

        case UIApplication.didEnterBackgroundNotification:
            event = .didEnterBackground(timestamp)
            kind = .didEnterBackground

        case UIApplication.willTerminateNotification:
            event = .willTerminate(timestamp)
            kind = .willTerminate

        default:
            return
        }

        let update = withLock { () -> Update in
            nextSequence += 1
            let record = EventRecord(
                kind: kind,
                timestamp: timestamp,
                applicationState: currentApplicationState(),
                sequence: nextSequence,
                source: .notification
            )
            eventHistory.append(record)
            if eventHistory.count > maxHistoryCount {
                eventHistory.removeFirst(eventHistory.count - maxHistoryCount)
            }

            updateSnapshot(for: event)
            return Update(event: event, eventRecord: record, snapshot: makeSnapshot())
        }

        let currentObservers = withLock { Array(observers.values) }
        for observer in currentObservers {
            observer(update)
        }
        #else
        _ = name
        #endif
    }

    private func updateSnapshot(for event: Event) {
        switch event {
        case let .didFinishLaunching(timestamp):
            if didFinishLaunchingTimestamp == nil {
                didFinishLaunchingTimestamp = timestamp
                updateLaunchOriginAtProcessStart()
            }

        case let .willEnterForeground(timestamp):
            if willEnterForegroundTimestamp == nil {
                willEnterForegroundTimestamp = timestamp
            }

            if launchOrigin == .unknown {
                if isBackgroundLaunch(timestamp: timestamp) {
                    launchOrigin = .background
                }
                else if let didFinishLaunchingTimestamp,
                    timestamp >= didFinishLaunchingTimestamp
                {
                    // willEnterForeground is the normal boundary for a user-visible
                    // cold launch. At this point an inactive application state is not
                    // enough reason to leave a valid foreground sequence unknown.
                    launchOrigin = .foreground
                }
            }

        case let .didBecomeActive(timestamp):
            if didBecomeActiveTimestamp == nil {
                didBecomeActiveTimestamp = timestamp
            }

            // A foreground launch can reach active without a foreground boundary.
            // Background launches are not considered foreground until the explicit
            // foreground boundary or the timing/state heuristic below identifies them.
            if launchOrigin == .unknown,
                willEnterForegroundTimestamp == nil,
                let didFinishLaunchingTimestamp,
                timestamp >= didFinishLaunchingTimestamp,
                timestamp.timeIntervalSince(didFinishLaunchingTimestamp) <= backgroundLaunchThreshold
            {
                launchOrigin = .foreground
            }

        case .didEnterBackground,
             .willResignActive,
             .willTerminate:
            break
        }
    }

    private func updateLaunchOriginAtProcessStart() {
        #if canImport(UIKit)
            if UIApplication.shared.applicationState == .background {
                launchOrigin = .background
            }
            else if UIApplication.shared.applicationState == .active {
                launchOrigin = .foreground
            }
        #endif
    }

    private func isBackgroundLaunch(timestamp: Date) -> Bool {
        #if canImport(UIKit)
            if UIApplication.shared.applicationState == .background {
                return true
            }
        #endif

        guard let didFinishLaunchingTimestamp else {
            return false
        }

        return timestamp.timeIntervalSince(didFinishLaunchingTimestamp) > backgroundLaunchThreshold
    }

    private func makeSnapshot() -> Snapshot {
        Snapshot(
            recorderStartedAt: recorderStartedAt,
            prewarmDetected: prewarmDetected,
            launchOrigin: launchOrigin,
            didFinishLaunching: didFinishLaunchingTimestamp,
            willEnterForeground: willEnterForegroundTimestamp,
            didBecomeActive: didBecomeActiveTimestamp,
            events: eventHistory
        )
    }

    private func captureInitialApplicationStateIfAvailable() {
        #if canImport(UIKit)
            guard Thread.isMainThread else {
                return
            }

            switch UIApplication.shared.applicationState {
            case .active:
                launchOrigin = .foreground

            case .background:
                launchOrigin = .background

            case .inactive:
                launchOrigin = .unknown

            @unknown default:
                launchOrigin = .unknown
            }
        #endif
    }

    private func currentApplicationState() -> ApplicationState {
        #if canImport(UIKit)
            switch UIApplication.shared.applicationState {
            case .active:
                return .active

            case .inactive:
                return .inactive

            case .background:
                return .background

            @unknown default:
                return .unknown
            }
        #else
            return .unknown
        #endif
    }

    private func observer(for identifier: UUID) -> ((Update) -> Void)? {
        withLock {
            observers[identifier]
        }
    }

    private func withLock<Result>(_ work: () -> Result) -> Result {
        lock.lock()
        defer { lock.unlock() }
        return work()
    }
}
