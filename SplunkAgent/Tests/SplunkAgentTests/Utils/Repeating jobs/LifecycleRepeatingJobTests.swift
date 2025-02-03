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

final class LifecycleRepeatingJobTests: XCTestCase {

    // MARK: - Constants

    private let defaultInterval: TimeInterval = 1

    // We need time to deliver and evaluate the expectations
    private let deliveryTime: TimeInterval = 0.1


    // MARK: - Private

    private var defaultJob: LifecycleRepeatingJob?
    private var counter: Int = 0


    // MARK: - XCTest lifecycle

    override func setUpWithError() throws {
        counter = 0

        // Default job initialized with minimal parameters
        defaultJob = LifecycleRepeatingJob(interval: defaultInterval) {
            self.counter += 1
        }
    }

    override func tearDown() {
        super.tearDown()

        defaultJob = nil
    }


    // MARK: - Job management

    func testLifecycle() throws {
        /* Going into the background for some time */
        try simulateBackgroundStay(for: DefaultSession(), duration: 5)

        /* SUSPENDED */
        // The job should stay suspended
        simulateMainThreadWait(duration: 3)
        XCTAssertEqual(counter, 0)

        defaultJob?.suspend()

        // `suspend()` on the suspended job does nothing
        simulateMainThreadWait(duration: 3)
        XCTAssertEqual(counter, 0)


        /* RESUMED */
        defaultJob?.resume()

        // `resume()` on the suspended job starts its execution
        let resumeDuration: TimeInterval = 1
        let resumeCount = executionsCount(for: resumeDuration)

        simulateMainThreadWait(duration: resumeDuration + deliveryTime)
        XCTAssertEqual(counter, resumeCount)

        // `resume()` on the resumed job does nothing
        defaultJob?.resume()
        let secondResumeDuration: TimeInterval = 2
        let secondResumeCount = executionsCount(for: secondResumeDuration) + resumeCount

        simulateMainThreadWait(duration: secondResumeDuration + deliveryTime)
        XCTAssertEqual(counter, secondResumeCount)
    }


    // MARK: - Application lifecycle

    func testEnterBackground() throws {
        let initialDuration: TimeInterval = 2
        let initialCount = executionsCount(for: initialDuration)


        // Job is suspended after initialization
        defaultJob?.resume()

        // After the resume, there should be some job executions
        simulateMainThreadWait(duration: initialDuration + deliveryTime)
        XCTAssertEqual(counter, initialCount)


        /* Going into the background */
        sendEnterBackgroundNotification()

        // After the background entry, another execution should be performed for this transition
        let afterEnterCount = initialCount + 1
        simulateMainThreadWait(duration: initialDuration + deliveryTime)
        XCTAssertEqual(counter, afterEnterCount)

        // If the application is in the background, the job should be suspended
        let suspended = try XCTUnwrap(defaultJob?.suspended)
        XCTAssertTrue(suspended)

        // Call to `suspend()` does nothing
        defaultJob?.suspend()

        simulateMainThreadWait(duration: initialDuration + deliveryTime)
        XCTAssertEqual(counter, afterEnterCount)

        // Call to `resume()` does nothing
        defaultJob?.resume()

        simulateMainThreadWait(duration: initialDuration + deliveryTime)
        XCTAssertEqual(counter, afterEnterCount)
    }

    func testEnterForeground() throws {
        let testName = "jobEntersForegroundTest"
        let defaultSession = try DefaultSessionTestBuilder.build(named: testName)

        let initialDuration: TimeInterval = 2
        let initialCount = executionsCount(for: initialDuration)


        // Job is suspended after initialization
        defaultJob?.resume()

        // After the resume, there should be some job executions
        simulateMainThreadWait(duration: initialDuration + deliveryTime)
        XCTAssertEqual(counter, initialCount)


        /* Going into the background for some time */
        let backgroundStay: UInt32 = 7
        try simulateBackgroundStay(for: defaultSession, duration: backgroundStay)

        // After a previous stay in the background, there should be two new ticks:
        // - 1x transition into background
        // - 1x transition to foreground
        let afterLeaveBackgroundCount = initialCount + 2

        simulateMainThreadWait(duration: deliveryTime)
        XCTAssertEqual(counter, afterLeaveBackgroundCount)


        // If the application is now in the foreground, the job should still be resumed
        let suspended = try XCTUnwrap(defaultJob?.suspended)
        XCTAssertFalse(suspended)


        // After the return, the job should continue its executions
        let foregroundDuration: TimeInterval = 3
        let foregroundCount = executionsCount(for: foregroundDuration)
        let finalCount = afterLeaveBackgroundCount + foregroundCount

        simulateMainThreadWait(duration: foregroundDuration + deliveryTime)
        XCTAssertEqual(counter, finalCount)
    }


    // MARK: - Private methods

    private func executionsCount(for interval: TimeInterval) -> Int {
        let ticks = interval / defaultInterval
        let executionsCount = Int(ticks.rounded(.down))

        return executionsCount
    }
}

#endif
// swiftformat:enable indent
