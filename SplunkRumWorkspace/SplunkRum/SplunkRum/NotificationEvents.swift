//
/*
Copyright 2021 Splunk Inc.

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
import UserNotifications
import UIKit

class NotificationEvents {

    @objc func receiveRemoteNotification(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {

        }

    private func swizzleDidReceiveRemoteNotification() {
        let appDelegate = UIApplication.shared.delegate
        let appDelegateClass: AnyClass? = object_getClass(appDelegate)

            let originalSelector = #selector(UIApplicationDelegate.application(_:didReceiveRemoteNotification:fetchCompletionHandler:))
            let swizzledSelector = #selector(NotificationEvents.self.receiveRemoteNotification(_:didReceiveRemoteNotification:fetchCompletionHandler:))

            guard let swizzledMethod = class_getInstanceMethod(NotificationEvents.self, swizzledSelector) else {
                return
            }

            if let originalMethod = class_getInstanceMethod(appDelegateClass, originalSelector) {
                // exchange implementation
                method_exchangeImplementations(originalMethod, swizzledMethod)
            } else {
                // add implementation
                class_addMethod(appDelegateClass, swizzledSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))
            }
    }
}
func userNotificationCenterTap(userInfo: UNNotificationResponse) {
    let userInf = userInfo.notification.request.content.userInfo
    print(userInf)
        let state = UIApplication.shared.applicationState
        if state == .inactive || state == .background {
            if let aps = userInf["aps"] as? NSDictionary {
                print(aps)
            }
        }
}
