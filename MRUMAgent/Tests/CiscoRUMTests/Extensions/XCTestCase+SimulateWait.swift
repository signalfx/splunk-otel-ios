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

extension XCTestCase {

    // MARK: - Simulated waiting

    /// Simulates the application running in time without interrupting it or putting the main thread to sleep.
    ///
    /// The method works as a non-blocking main thread. Thus, it can be used while waiting for a result
    /// or for an operation to complete.
    ///
    /// The method suspends the linear execution of the test but not the execution of the code under test,
    /// which differs from other options, such as the `sleep()` method.
    ///
    /// - Parameter duration: A waiting time in seconds.
    func simulateMainThreadWait(duration: TimeInterval) {
        // We need time to deliver and evaluate the expectation for the whole mechanism to work correctly.
        // This time window will guarantee that there will always be enough time for the expectation
        // to be satisfied and the `wait(for:timeout:)` method to always complete correctly.
        let deliveryTime: TimeInterval = 0.05

        // Simulate waiting on the main thread
        let waitExpectation = XCTestExpectation(description: "Waiting for \(duration) seconds.")
        let fireDuration: DispatchTime = .now() + duration - deliveryTime

        DispatchQueue.main.asyncAfter(deadline: fireDuration) {
            waitExpectation.fulfill()
        }

        wait(for: [waitExpectation], timeout: duration)
    }
}
