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

@testable import SplunkCommon
@testable import SplunkCrashReports

// MARK: - Mock

final class MockAgentSharedState: AgentSharedState, @unchecked Sendable {
    var sessionId: String = "mock-session-id"
    var agentVersion: String = "1.0.0"

    func applicationState(for _: Date) -> String? {
        "foreground"
    }
}

// MARK: - Tests

final class CrashReportsTests: XCTestCase {

    // MARK: - Private

    private var crashReports: CrashReports?


    // MARK: - Tests lifecycle

    override func setUp() {
        super.setUp()
        crashReports = CrashReports()
    }

    override func tearDown() {
        crashReports = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testCrashReportsInitialization() {
        let instance = CrashReports()

        XCTAssertNotNil(instance)
        XCTAssertNil(instance.sharedState)
        XCTAssertTrue(instance.allUsedImageNames.isEmpty)
    }

    func testCrashReportsSharedStateCanBeSet() {
        // Create a mock shared state
        let mockSharedState = MockAgentSharedState()

        crashReports?.sharedState = mockSharedState

        XCTAssertNotNil(crashReports?.sharedState)
    }

    // MARK: - Configuration Tests

    func testCrashReportsConfigureCrashReporterDoesNotThrow() {
        // This should not throw or crash
        XCTAssertNoThrow(crashReports?.configureCrashReporter())
    }

    func testCrashReportsConfigureCrashReporterCanBeCalledMultipleTimes() {
        // Calling multiple times should be safe
        crashReports?.configureCrashReporter()
        crashReports?.configureCrashReporter()

        // If we reach here, multiple calls are safe
        XCTAssertTrue(true)
    }

    // MARK: - Crash Report Detection Tests

    func testCrashReportsReportCrashIfPresentWithoutConfiguration() {
        // Calling without configuration should handle gracefully
        XCTAssertNoThrow(crashReports?.reportCrashIfPresent())
    }

    func testCrashReportsReportCrashIfPresentWithConfiguration() {
        crashReports?.configureCrashReporter()

        // Should not throw
        XCTAssertNoThrow(crashReports?.reportCrashIfPresent())
    }

    // MARK: - Data Consumer Tests

    func testCrashReportsCrashReportDataConsumerCanBeSet() {
        var consumerCalled = false

        crashReports?.crashReportDataConsumer = { _, _ in
            consumerCalled = true
        }

        XCTAssertNotNil(crashReports?.crashReportDataConsumer)

        // Verify it can be called
        crashReports?.crashReportDataConsumer?(CrashReportsMetadata(), "test")
        XCTAssertTrue(consumerCalled)
    }

    func testCrashReportsCrashReportDataConsumerCanBeCleared() {
        crashReports?.crashReportDataConsumer = { _, _ in }

        XCTAssertNotNil(crashReports?.crashReportDataConsumer)

        crashReports?.crashReportDataConsumer = nil

        XCTAssertNil(crashReports?.crashReportDataConsumer)
    }

    // MARK: - Image Names Tests

    func testCrashReportsAllUsedImageNamesInitiallyEmpty() {
        XCTAssertTrue(crashReports?.allUsedImageNames.isEmpty ?? false)
    }

    func testCrashReportsAllUsedImageNamesCanBePopulated() {
        crashReports?.allUsedImageNames = ["image1.dylib", "image2.framework"]

        XCTAssertEqual(crashReports?.allUsedImageNames.count, 2)
        XCTAssertTrue(crashReports?.allUsedImageNames.contains("image1.dylib") ?? false)
        XCTAssertTrue(crashReports?.allUsedImageNames.contains("image2.framework") ?? false)
    }

    // MARK: - Span Name Tests

    func testCrashReportsDefaultSpanName() {
        XCTAssertEqual(crashReports?.crashSpanName, "SplunkCrashReport")
    }

    func testCrashReportsUpdateSpanNameWithSignalName() {
        crashReports?.updateSpanName("SIGABRT")

        XCTAssertEqual(crashReports?.crashSpanName, "SIGABRT")
    }

    func testCrashReportsUpdateSpanNameWithExceptionName() {
        crashReports?.updateSpanName("NSInvalidArgumentException")

        XCTAssertEqual(crashReports?.crashSpanName, "NSInvalidArgumentException")
    }

    func testCrashReportsUpdateSpanNameExceptionOverridesSignal() {
        // Simulates the flow in formatCrashReport where signal name is set first,
        // then exception name overrides it if present
        crashReports?.updateSpanName("SIGABRT")
        XCTAssertEqual(crashReports?.crashSpanName, "SIGABRT")

        crashReports?.updateSpanName("NSInvalidArgumentException")
        XCTAssertEqual(crashReports?.crashSpanName, "NSInvalidArgumentException")
    }

    func testCrashReportsUpdateSpanNameWithEmptyStringDoesNotUpdate() {
        // First set a valid name
        crashReports?.updateSpanName("SIGABRT")
        XCTAssertEqual(crashReports?.crashSpanName, "SIGABRT")

        // Empty string should not change the span name
        crashReports?.updateSpanName("")
        XCTAssertEqual(crashReports?.crashSpanName, "SIGABRT")
    }

    // MARK: - Lifecycle Tests

    func testCrashReportsDeinitDoesNotCrash() {
        var instance: CrashReports? = CrashReports()
        instance?.configureCrashReporter()

        // Deinitializing should not crash
        instance = nil

        XCTAssertNil(instance)
    }

    func testCrashReportsDeinitWithDataConsumer() {
        var instance: CrashReports? = CrashReports()
        instance?.crashReportDataConsumer = { _, _ in }

        // Deinitializing with data consumer should not crash
        instance = nil

        XCTAssertNil(instance)
    }
}
