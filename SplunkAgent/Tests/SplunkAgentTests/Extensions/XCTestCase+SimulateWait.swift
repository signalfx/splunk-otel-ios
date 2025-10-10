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
        let exp = expectation(description: "Test delayed by \(duration) seconds")
        let result = XCTWaiter.wait(for: [exp], timeout: duration)

        guard result == XCTWaiter.Result.timedOut else {
            XCTFail("Delay interrupted")

            return
        }
    }
}
