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

@testable import SplunkCrashReports

final class CrashReportsTests: XCTestCase {

    var crashReports: CrashReports!

    override func setUp() {
        super.setUp()
        crashReports = CrashReports()
    }

    override func tearDown() {
        crashReports = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testCrashReports_Initialization() {
        let instance = CrashReports()

        XCTAssertNotNil(instance)
        XCTAssertNil(instance.sharedState)
        XCTAssertTrue(instance.allUsedImageNames.isEmpty)
    }

    // MARK: - Configuration Tests

    func testCrashReports_ConfigureCrashReporter_DoesNotThrow() {
        // This should not throw or crash
        XCTAssertNoThrow(crashReports.configureCrashReporter())
    }

    func testCrashReports_ConfigureCrashReporter_CanBeCalledMultipleTimes() {
        // Calling multiple times should be safe
        crashReports.configureCrashReporter()
        crashReports.configureCrashReporter()

        // If we reach here, multiple calls are safe
        XCTAssertTrue(true)
    }

    // MARK: - Crash Report Detection Tests

    func testCrashReports_ReportCrashIfPresent_WithoutConfiguration() {
        // Calling without configuration should handle gracefully
        XCTAssertNoThrow(crashReports.reportCrashIfPresent())
    }

    func testCrashReports_ReportCrashIfPresent_WithConfiguration() {
        crashReports.configureCrashReporter()

        // Should not throw
        XCTAssertNoThrow(crashReports.reportCrashIfPresent())
    }

    // MARK: - Data Consumer Tests

    func testCrashReports_CrashReportDataConsumer_CanBeSet() {
        var consumerCalled = false

        crashReports.crashReportDataConsumer = { _, _ in
            consumerCalled = true
        }

        XCTAssertNotNil(crashReports.crashReportDataConsumer)

        // Verify it can be called
        crashReports.crashReportDataConsumer?(CrashReportsMetadata(), "test")
        XCTAssertTrue(consumerCalled)
    }

    func testCrashReports_CrashReportDataConsumer_CanBeCleared() {
        crashReports.crashReportDataConsumer = { _, _ in }

        XCTAssertNotNil(crashReports.crashReportDataConsumer)

        crashReports.crashReportDataConsumer = nil

        XCTAssertNil(crashReports.crashReportDataConsumer)
    }

    // MARK: - Image Names Tests

    func testCrashReports_AllUsedImageNames_InitiallyEmpty() {
        XCTAssertTrue(crashReports.allUsedImageNames.isEmpty)
    }

    func testCrashReports_AllUsedImageNames_CanBePopulated() {
        crashReports.allUsedImageNames = ["image1.dylib", "image2.framework"]

        XCTAssertEqual(crashReports.allUsedImageNames.count, 2)
        XCTAssertTrue(crashReports.allUsedImageNames.contains("image1.dylib"))
        XCTAssertTrue(crashReports.allUsedImageNames.contains("image2.framework"))
    }

    // MARK: - Lifecycle Tests

    func testCrashReports_Deinit_DoesNotCrash() {
        var instance: CrashReports? = CrashReports()
        instance?.configureCrashReporter()

        // Deinitializing should not crash
        instance = nil

        XCTAssertNil(instance)
    }

    func testCrashReports_Deinit_WithDataConsumer() {
        var instance: CrashReports? = CrashReports()
        instance?.crashReportDataConsumer = { _, _ in }

        // Deinitializing with data consumer should not crash
        instance = nil

        XCTAssertNil(instance)
    }
}
