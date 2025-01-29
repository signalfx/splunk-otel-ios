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

final class RepeatingJobTests: XCTestCase {

    // MARK: - Constants

    private let defaultInterval: TimeInterval = 1


    // MARK: - Private

    private var defaultJob: RepeatingJob?


    // MARK: - XCTest lifecycle

    override func setUpWithError() throws {
        // Default job initialized with minimal parameters
        defaultJob = RepeatingJob(interval: defaultInterval) {}
    }

    override func tearDown() {
        super.tearDown()

        defaultJob = nil
    }


    // MARK: - Basic logic

    func testInitialization() throws {
        let simpleJob = RepeatingJob(interval: 1) {
            // Does nothing
        }
        XCTAssertNotNil(simpleJob)


        let namedJob = RepeatingJob(named: "TestJob", interval: 2) {
            // Does nothing
        }
        XCTAssertNotNil(namedJob)
    }


    // MARK: - Business logic

    func testProperties() throws {
        let resumedName = "Test Job"
        let resumedInterval: TimeInterval = 2

        // Started job with extended parameters
        let resumedJob = RepeatingJob(
            named: resumedName,
            interval: resumedInterval
        ) {}.resume()

        // Default job is suspended after initialization
        let suspendedJob = try XCTUnwrap(defaultJob)


        // Suspended job should indicate its state
        XCTAssertTrue(suspendedJob.suspended)
        XCTAssertNil(suspendedJob.name)
        XCTAssertEqual(suspendedJob.interval, defaultInterval)

        // Resumed job should indicate that is not suspended
        XCTAssertFalse(resumedJob.suspended)

        let name = try XCTUnwrap(resumedJob.name)
        XCTAssertEqual(name, resumedName)
        XCTAssertEqual(resumedJob.interval, resumedInterval)
    }


    // MARK: - Job management

    func testManagementMethods() throws {
        // Default job is suspended after initialization
        let job = try XCTUnwrap(defaultJob)


        /* RESUME */
        // `resume()` method should return `self`
        let resumeReturnValue = job.resume()
        XCTAssertTrue(resumeReturnValue === job)
        XCTAssertFalse(job.suspended)

        /* SUSPEND */
        // `suspend()` method should return `self`
        let suspendReturnValue = job.suspend()
        XCTAssertTrue(suspendReturnValue === job)
        XCTAssertTrue(job.suspended)
    }

    func testLifecycle() throws {
        var counter = 0

        // Job is suspended after initialization
        let job = RepeatingJob(interval: 2) {
            counter += 1
        }


        /* SUSPENDED */
        // The job should stay suspended
        simulateMainThreadWait(duration: 3)
        XCTAssertEqual(counter, 0)

        job.suspend()

        // `suspend()` on the suspended job does nothing
        simulateMainThreadWait(duration: 3)
        XCTAssertEqual(counter, 0)


        /* RESUMED */
        job.resume()

        // `resume()` on the suspended job starts its execution
        simulateMainThreadWait(duration: 3)
        XCTAssertEqual(counter, 1)

        job.resume()

        // `resume()` on the resumed job does nothing
        simulateMainThreadWait(duration: 4)
        XCTAssertEqual(counter, 3)
    }
}
