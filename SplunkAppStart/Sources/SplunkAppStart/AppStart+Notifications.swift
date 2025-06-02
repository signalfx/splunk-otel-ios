//
/*
Copyright 2024 Splunk Inc.

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

    /// Start listening to UIApplication app lifecycle notifications.
    func startNotificationListeners() {

        // Don't start listening if we are already are listening
        if notificationTokens != nil {
            return
        }

        var tokens = [NSObjectProtocol]()

        // didFinishLaunching notification - store the notification timestamp
        listen(to: UIApplication.didFinishLaunchingNotification, in: &tokens) {
            self.didFinishLaunchingTimestamp = Date()

            self.logger.log(level: .debug) { "UIApplication.didFinishLaunchingNotification triggered" }
        }

        // willEnterForeground notification - store the notification timestamp and detect a background launch
        listen(to: UIApplication.willEnterForegroundNotification, in: &tokens) {
            self.willEnterForegroundTimestamp = Date()

            // detect background launch, but only once
            if self.backgroundLaunchDetected == nil, UIApplication.shared.applicationState == .background {
                self.backgroundLaunchDetected = true
            }

            self.logger.log(level: .debug) { "UIApplication.willEnterForegroundNotification triggered" }
        }

        // didBecomeActive notification - store the timestamp, determine app start type and send results
        listen(to: UIApplication.didBecomeActiveNotification, in: &tokens) {
            self.didBecomeActiveTimestamp = Date()

            if self.backgroundLaunchDetected == nil {
                self.backgroundLaunchDetected = false
            }

            self.logger.log(level: .debug) { "UIApplication.didBecomeActiveNotification triggered" }

            self.determineAndSend()
        }

        // willResignActive notification - store the timestamp
        listen(to: UIApplication.willResignActiveNotification, in: &tokens) {
            self.willResignActiveTimestamp = Date()

            self.logger.log(level: .debug) { "UIApplication.willResignActiveNotification triggered" }
        }

        // didEnterBackground notification - no op atm
        listen(to: UIApplication.didEnterBackgroundNotification, in: &tokens) {
            self.logger.log(level: .debug) { "UIApplication.didEnterBackgroundNotification triggered" }
        }

        notificationTokens = tokens
    }

    /// Stop listening to UIApplication app lifecycle notifications.
    func stopNotificationListeners() {
        if let notificationTokens {
            for notificationToken in notificationTokens {
                NotificationCenter.default.removeObserver(notificationToken)
            }

            self.notificationTokens = nil
        }
    }

    private func listen(to name: Notification.Name, in tokens: inout [NSObjectProtocol], handler: @escaping () -> Void) {
        let token = NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { _ in
            handler()
        }

        tokens.append(token)
    }
}
