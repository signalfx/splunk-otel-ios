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

import UIKit

extension AppStart {

    // MARK: - Notification observation

    /// Starts the module's single lifecycle observer.
    func startNotificationListeners() {
        notificationLock.lock()
        defer { notificationLock.unlock() }

        guard notificationTokens == nil else {
            return
        }

        notificationGeneration &+= 1
        let generation = notificationGeneration
        var tokens: [NSObjectProtocol] = []

        listenForLaunch(in: &tokens, generation: generation)
        listen(
            to: UIApplication.willEnterForegroundNotification,
            in: &tokens,
            generation: generation,
            event: { _, timestamp in .willEnterForeground(timestamp) }
        )
        listen(
            to: UIApplication.didBecomeActiveNotification,
            in: &tokens,
            generation: generation,
            event: { _, timestamp in .didBecomeActive(timestamp) }
        )
        listen(
            to: UIApplication.willResignActiveNotification,
            in: &tokens,
            generation: generation,
            event: { _, _ in .willResignActive }
        )
        listen(
            to: UIApplication.didEnterBackgroundNotification,
            in: &tokens,
            generation: generation,
            event: { _, _ in .didEnterBackground }
        )
        listen(
            to: UIApplication.willTerminateNotification,
            in: &tokens,
            generation: generation,
            event: { _, _ in .willTerminate }
        )

        notificationTokens = tokens
    }

    private func listenForLaunch(
        in tokens: inout [NSObjectProtocol],
        generation: UInt64
    ) {
        listen(
            to: UIApplication.didFinishLaunchingNotification,
            in: &tokens,
            generation: generation,
            event: { notification, timestamp in
                guard Thread.isMainThread else {
                    return .didFinishLaunching(timestamp, .unknown)
                }

                // This closure is on the main thread, including the shared-app fallback.
                let application = notification.object as? UIApplication
                let applicationState = application.map(\.applicationState) ?? UIApplication.shared.applicationState

                return .didFinishLaunching(
                    timestamp,
                    Self.launchOrigin(for: applicationState)
                )
            }
        )
    }

    /// Stops listening to lifecycle notifications.
    func stopNotificationListeners(invalidateState: Bool) {
        // Lock order is notificationLock, then the state lock inside prepare(event:).
        notificationLock.lock()

        guard let notificationTokens else {
            notificationLock.unlock()
            return
        }

        notificationGeneration &+= 1
        self.notificationTokens = nil

        let output =
            invalidateState
            ? prepare(event: .observationGap)
            : nil

        notificationLock.unlock()

        // Remove old tokens outside the lock. Their generation is already invalid,
        // so callbacks cannot mutate state while NotificationCenter tears them down.
        for notificationToken in notificationTokens {
            NotificationCenter.default.removeObserver(notificationToken)
        }

        if let output {
            perform(output)
        }
    }

    private func listen(
        to name: Notification.Name,
        in tokens: inout [NSObjectProtocol],
        generation: UInt64,
        event: @escaping (Notification, Date) -> AppStartReducer.Event
    ) {
        let token = NotificationCenter.default.addObserver(
            forName: name,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            let timestamp = Date()

            guard let self else {
                return
            }

            logger.log(level: .debug) {
                "\(name.rawValue) triggered"
            }
            processObserved(
                event: event(notification, timestamp),
                generation: generation
            )
        }

        tokens.append(token)
    }

    private func processObserved(
        event: AppStartReducer.Event,
        generation: UInt64
    ) {
        // Lock order is notificationLock, then the state lock inside prepare(event:).
        notificationLock.lock()

        guard notificationTokens != nil,
            generation == notificationGeneration
        else {
            notificationLock.unlock()
            return
        }

        let output = prepare(event: event)
        notificationLock.unlock()

        perform(output)
    }

    private static func launchOrigin(
        for applicationState: UIApplication.State
    ) -> AppStartReducer.LaunchOrigin {
        switch applicationState {
        case .active,
            .inactive:
            return .foreground

        case .background:
            return .background

        @unknown default:
            return .unknown
        }
    }
}
