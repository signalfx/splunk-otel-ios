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

import XCTest

// swiftformat:disable indent
#if os(iOS) || os(tvOS) || os(visionOS)

extension XCTestCase {

    // MARK: - Constants

    /// We need time to deliver and evaluate the expectations.
    private var deliveryTime: TimeInterval {
        0.05
    }


    // MARK: - Simulated UIKit notifications

    /// Simulates sending for `didEnterBackgroundNotification` from the system.
    func sendEnterBackgroundNotification() {
        // Send notification emitted from simulated UIKit
        sendSimulatedNotification(UIApplication.didEnterBackgroundNotification)
    }

    /// Simulates sending for `willEnterForegroundNotification` from the system.
    func sendEnterForegroundNotification() {
        // Send notification emitted from simulated UIKit
        sendSimulatedNotification(UIApplication.willEnterForegroundNotification)
    }


    // MARK: - Simulated notifications

    /// Simulates sending a notification as in the case of a running application.
    func sendSimulatedNotification(_ notification: NSNotification.Name) {
        // Watch for emitted notification
        _ = expectation(
            forNotification: notification,
            object: nil,
            handler: nil
        )

        // Send simulated notification
        NotificationCenter.default.post(
            name: notification,
            object: nil
        )

        // We need to wait for notification delivery
        waitForExpectations(timeout: deliveryTime, handler: nil)
    }
}

#endif
// swiftformat:enable indent
