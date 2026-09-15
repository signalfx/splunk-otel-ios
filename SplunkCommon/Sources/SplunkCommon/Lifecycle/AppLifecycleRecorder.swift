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

/// Records the process' initial application lifecycle evidence for the agent core.
///
/// The recorder is shared by AppStart, AppState, and hybrid integrations. Initial
/// lifecycle fields use first-event-wins semantics; subsequent lifecycle events are
/// still delivered to subscribers so AppState can persist every transition.
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

    /// The first-launch evidence currently known by the recorder.
    @_spi(SplunkInternal)
    public struct Snapshot {
        public let launchOrigin: LaunchOrigin
        public let didFinishLaunching: Date?
        public let willEnterForeground: Date?
        public let didBecomeActive: Date?

        fileprivate init(
            launchOrigin: LaunchOrigin,
            didFinishLaunching: Date?,
            willEnterForeground: Date?,
            didBecomeActive: Date?
        ) {
            self.launchOrigin = launchOrigin
            self.didFinishLaunching = didFinishLaunching
            self.willEnterForeground = willEnterForeground
            self.didBecomeActive = didBecomeActive
        }
    }

    /// An update containing the latest snapshot and the event that caused it.
    @_spi(SplunkInternal)
    public struct Update {
        public let event: Event?
        public let snapshot: Snapshot

        fileprivate init(event: Event?, snapshot: Snapshot) {
            self.event = event
            self.snapshot = snapshot
        }
    }

    // MARK: - Private properties

    private let notificationCenter: NotificationCenter
    private let lock = NSLock()
    private let backgroundLaunchThreshold: TimeInterval = 10.0

    private var notificationTokens: [NSObjectProtocol] = []
    private var observers: [UUID: (Update) -> Void] = [:]

    private var launchOrigin: LaunchOrigin = .unknown
    private var didFinishLaunchingTimestamp: Date?
    private var willEnterForegroundTimestamp: Date?
    private var didBecomeActiveTimestamp: Date?

    // MARK: - Initialization

    /// Creates and starts a lifecycle recorder.
    @_spi(SplunkInternal)
    public init(notificationCenter: NotificationCenter = .default, enabled: Bool = true) {
        self.notificationCenter = notificationCenter

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

    /// Subscribes to lifecycle updates and asynchronously receives the current snapshot first.
    @_spi(SplunkInternal)
    @discardableResult
    public func addObserver(_ observer: @escaping (Update) -> Void) -> UUID {
        let identifier = UUID()
        let snapshot = withLock { () -> Snapshot in
            observers[identifier] = observer
            return makeSnapshot()
        }

        DispatchQueue.main.async { [weak self] in
            guard let observer = self?.observer(for: identifier) else {
                return
            }

            observer(Update(event: nil, snapshot: snapshot))
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

        switch name {
        case UIApplication.didFinishLaunchingNotification:
            event = .didFinishLaunching(timestamp)

        case UIApplication.willEnterForegroundNotification:
            event = .willEnterForeground(timestamp)

        case UIApplication.didBecomeActiveNotification:
            event = .didBecomeActive(timestamp)

        case UIApplication.willResignActiveNotification:
            event = .willResignActive(timestamp)

        case UIApplication.didEnterBackgroundNotification:
            event = .didEnterBackground(timestamp)

        case UIApplication.willTerminateNotification:
            event = .willTerminate(timestamp)

        default:
            return
        }

        let update = withLock { () -> Update in
            updateSnapshot(for: event)
            return Update(event: event, snapshot: makeSnapshot())
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
            launchOrigin: launchOrigin,
            didFinishLaunching: didFinishLaunchingTimestamp,
            willEnterForeground: willEnterForegroundTimestamp,
            didBecomeActive: didBecomeActiveTimestamp
        )
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
