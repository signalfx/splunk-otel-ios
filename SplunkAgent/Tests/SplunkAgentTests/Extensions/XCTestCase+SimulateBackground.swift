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

@testable import SplunkAgent
import XCTest

// swiftformat:disable indent
#if os(iOS) || os(tvOS) || os(visionOS)

extension XCTestCase {

    // MARK: - Simulated background

    func simulateBackgroundStay(for defaultSession: DefaultSession, duration: UInt32) throws {
        let previousInterval = defaultSession.sessionRefreshInterval

        // The current interval also needs to be rolled back
        _ = Task {
            let sleepDuration = previousInterval + 1
            let sleepInterval = UInt64(sleepDuration * 1_000_000_000)
            try await Task.sleep(nanoseconds: sleepInterval)

            defaultSession.sessionRefreshInterval = previousInterval
        }

        // Watch for notification emitted from simulated UIKit
        _ = expectation(
            forNotification: UIApplication.didEnterBackgroundNotification,
            object: nil,
            handler: nil
        )

        // Send simulated enter into background
        NotificationCenter.default.post(
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        // We need to simulate a stay in the background for N seconds
        //
        // NOTE:
        // If an application goes into the background, its tasks also go to sleep.
        // After the application goes into the foreground, they resume.
        //
        // For this test, we can simulate the same behavior by setting
        // the internal refresh interval of the class.
        defaultSession.sessionRefreshInterval = Double(duration)
        sleep(duration)

        // We need to wait for notification delivery
        waitForExpectations(timeout: TimeInterval(duration), handler: nil)

        // Send simulated leave from background
        NotificationCenter.default.post(
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
}

#endif
// swiftformat:enable indent
