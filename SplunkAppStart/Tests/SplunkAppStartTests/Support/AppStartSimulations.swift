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

import XCTest

@testable import SplunkAppStart

func simulateColdStartNotifications() {
    NotificationCenter.default.post(name: UIApplication.didFinishLaunchingNotification, object: nil)
    NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
    NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
}

func simulateWarmStartNotifications() {
    NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
    NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
}

func simulateHotStartNotifications() {
    NotificationCenter.default.post(name: UIApplication.didFinishLaunchingNotification, object: nil)
    NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
    NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
    NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
    NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
    NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
}

func simulateStartNotificationsWithNoDidFinishLaunching() {
    NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
    NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
}
