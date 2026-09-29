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

extension AppLifecycleRecorder {

    // MARK: - Lifecycle observation

    func start() {
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
                    self?.record(notification)
                }

                notificationTokens.append(token)
            }
        #endif
    }

    func stop() {
        for token in notificationTokens {
            notificationCenter.removeObserver(token)
        }

        notificationTokens.removeAll()
    }

    func record(_ notification: Notification) {
        #if canImport(UIKit)
            let name = notification.name
            let timestamp = Date()
            guard let lifecycleEvent = lifecycleEvent(for: name, at: timestamp) else {
                return
            }

            let update = makeUpdate(
                event: lifecycleEvent.event,
                kind: lifecycleEvent.kind,
                timestamp: timestamp,
                notification: notification
            )

            let currentObservers = withLock {
                // Pending observers intentionally receive the event through the
                // initial snapshot. AppStart and AppState replay snapshot.events,
                // which preserves snapshot-before-event ordering without blocking
                // the hybrid bridge thread.
                observers.values.compactMap { observer in
                    observer.initialSnapshotDelivered ? observer.callback : nil
                }
            }
            for observer in currentObservers {
                observer(update)
            }
        #else
            _ = notification
        #endif
    }

    func updateSnapshot(for event: Event) {
        switch event {
        case let .didFinishLaunching(timestamp):
            updateAfterDidFinishLaunching(timestamp)

        case let .willEnterForeground(timestamp):
            updateAfterWillEnterForeground(timestamp)

        case let .didBecomeActive(timestamp):
            updateAfterDidBecomeActive(timestamp)

        case .didEnterBackground,
            .willResignActive,
            .willTerminate:
            break
        }
    }

    private func lifecycleEvent(
        for name: Notification.Name,
        at timestamp: Date
    ) -> (event: Event, kind: EventKind)? {
        switch name {
        case UIApplication.didFinishLaunchingNotification:
            return (.didFinishLaunching(timestamp), .didFinishLaunching)

        case UIApplication.willEnterForegroundNotification:
            return (.willEnterForeground(timestamp), .willEnterForeground)

        case UIApplication.didBecomeActiveNotification:
            return (.didBecomeActive(timestamp), .didBecomeActive)

        case UIApplication.willResignActiveNotification:
            return (.willResignActive(timestamp), .willResignActive)

        case UIApplication.didEnterBackgroundNotification:
            return (.didEnterBackground(timestamp), .didEnterBackground)

        case UIApplication.willTerminateNotification:
            return (.willTerminate(timestamp), .willTerminate)

        default:
            return nil
        }
    }

    private func makeUpdate(
        event: Event,
        kind: EventKind,
        timestamp: Date,
        notification: Notification
    ) -> Update {
        withLock {
            nextSequence += 1
            let record = EventRecord(
                kind: kind,
                timestamp: timestamp,
                applicationState: currentApplicationState(),
                launchOptionKeys: launchOptionKeys(from: notification),
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
    }

    private func updateAfterDidFinishLaunching(_ timestamp: Date) {
        guard didFinishLaunchingTimestamp == nil else {
            return
        }

        didFinishLaunchingTimestamp = timestamp
        updateLaunchOriginAtProcessStart()
    }

    private func updateAfterWillEnterForeground(_ timestamp: Date) {
        if willEnterForegroundTimestamp == nil {
            willEnterForegroundTimestamp = timestamp
        }

        guard launchOrigin == .unknown else {
            return
        }

        if isBackgroundLaunch(timestamp: timestamp) {
            launchOrigin = .background
            launchOriginConfidence =
                eventHistory.contains {
                    $0.kind == .didEnterBackground
                } ? .observed : .inferred
        }
        else if let didFinishLaunchingTimestamp,
            timestamp >= didFinishLaunchingTimestamp
        {
            // willEnterForeground is the normal boundary for a user-visible
            // cold launch. At this point an inactive application state is not
            // enough reason to leave a valid foreground sequence unknown.
            launchOrigin = .foreground
            launchOriginConfidence = .observed
        }
    }

    private func updateAfterDidBecomeActive(_ timestamp: Date) {
        if didBecomeActiveTimestamp == nil {
            didBecomeActiveTimestamp = timestamp
        }

        // A foreground launch can reach active without a foreground boundary.
        // Background launches are not considered foreground until the explicit
        // foreground boundary or the timing/state heuristic below identifies them.
        guard launchOrigin == .unknown,
            willEnterForegroundTimestamp == nil,
            let didFinishLaunchingTimestamp,
            timestamp >= didFinishLaunchingTimestamp
        else {
            return
        }

        launchOrigin = .foreground
        launchOriginConfidence = .observed
    }
}
