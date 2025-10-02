//
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

#if os(iOS) || os(tvOS) || os(visionOS)
    import UIKit
#endif

extension AppStateModule {

    // MARK: - Setup notifications

    func setupNotifications() {
        #if os(iOS) || os(tvOS) || os(visionOS)
            removeNotifications()

            addObserver(UIApplication.didBecomeActiveNotification) { [weak self] in
                self?.processEvent(.active)
            }

            addObserver(UIApplication.didEnterBackgroundNotification) { [weak self] in
                self?.processEvent(.background)
            }

            addObserver(UIApplication.willEnterForegroundNotification) { [weak self] in
                self?.processEvent(.foreground)
            }

            addObserver(UIApplication.willResignActiveNotification) { [weak self] in
                self?.processEvent(.inactive)
            }

            addObserver(UIApplication.willTerminateNotification) { [weak self] in
                self?.processEvent(.terminate)
            }
        #endif
    }

    func removeNotifications() {
        #if os(iOS) || os(tvOS) || os(visionOS)
            let tokens = notificationObservers
            notificationObservers.removeAll()

            for token in tokens {
                NotificationCenter.default.removeObserver(token)
            }
        #endif
    }


    // MARK: - Private functions

    private func addObserver(_ name: Notification.Name, handler: @escaping () -> Void) {
        let token = NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { [weak self] _ in
            guard self != nil else {
                return
            }

            handler()
        }
        var tokens = notificationObservers
        tokens.append(token)
        notificationObservers = tokens
    }
}
