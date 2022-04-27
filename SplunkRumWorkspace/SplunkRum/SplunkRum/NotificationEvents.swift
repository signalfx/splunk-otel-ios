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

func userNotificationCenterTap(userInfo: UNNotificationResponse) {
    let userInf = userInfo.notification.request.content.userInfo
        let state = UIApplication.shared.applicationState
        if state == .inactive || state == .background {
            if let aps = userInf["aps"] as? NSDictionary {
                    if let alert = aps["alert"] as? NSDictionary {
                        if let message = alert["message"] as? String {
                            reportNotificationTapSpan(apns: message)
                        }
                    }
            }
        }
}
func reportNotificationTapSpan(apns: String) {
    let tracer = buildTracer()
    let now = Date()
    let typeName = "notificationTap"
    let span = tracer.spanBuilder(spanName: typeName).setStartTime(time: now).startSpan()
    span.setAttribute(key: "component", value: "ui")
    span.setAttribute(key: "screen.name", value: getScreenName())
    span.setAttribute(key: "message", value: apns)
    span.end(time: now)
}
