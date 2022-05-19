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

    @objc func userNotificationCenterTap(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let state = UIApplication.shared.applicationState
        if state == .inactive || state == .background {
            let tracer = buildTracer()
            let now = Date()
            let typeName = "notificationTap"
            let span = tracer.spanBuilder(spanName: typeName).setStartTime(time: now).startSpan()
            span.setAttribute(key: "component", value: "ui")
            span.setAttribute(key: "screen.name", value: getScreenName())
            span.end(time: now)
       }

    }
}

func swizzleDidReceiveRemoteNotification() {
    DispatchQueue.main.async {
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil,
        queue: OperationQueue.main, using: { _ in
            if UIApplication.shared.isRegisteredForRemoteNotifications {
                let appDelegate = UIApplication.shared.delegate
                let appDelegateClass: AnyClass? = object_getClass(appDelegate)
                let originalSelector = #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:))
                let swizzledSelector = #selector(NotificationEvents.self.userNotificationCenterTap(_:didReceive:withCompletionHandler:))
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
        })
    }
}
