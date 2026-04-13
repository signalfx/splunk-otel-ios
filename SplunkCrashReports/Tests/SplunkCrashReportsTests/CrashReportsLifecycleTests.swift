//
/*
Copyright 2026 Splunk Inc.

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
import XCTest

@testable import SplunkCommon
@testable import SplunkCrashReports

/// Tests for `initializeCrashReporter`, `crashReportUpdateScreenName`,
/// and `appStateHandler` in `CrashReports.swift`.
///
/// `appStateHandler(report:)` requires a `PLCrashReport` instance and
/// can only be fully tested with real crash data. The shared-state
/// integration is verified via mock instead.
final class CrashReportsLifecycleTests: XCTestCase {

    // MARK: - initializeCrashReporter

    func testInitializeWithoutConfigureReturnsFalse() {
        let crashReports = CrashReports()

        // crashReporter is nil because configureCrashReporter was not called
        let result = crashReports.initializeCrashReporter()

        XCTAssertFalse(result)
    }

    func testInitializeAfterConfigureDoesNotCrash() {
        let crashReports = CrashReports()
        crashReports.configureCrashReporter()

        // Result depends on environment: false when a debugger is attached
        // (Xcode), true in CI where no debugger is present. Both are valid.
        _ = crashReports.initializeCrashReporter()
    }

    // MARK: - crashReportUpdateScreenName

    func testUpdateScreenNameDoesNotThrow() {
        let crashReports = CrashReports()

        XCTAssertNoThrow(crashReports.crashReportUpdateScreenName("HomeScreen"))
    }

    func testUpdateScreenNameWithEmptyStringDoesNotThrow() {
        let crashReports = CrashReports()

        XCTAssertNoThrow(crashReports.crashReportUpdateScreenName(""))
    }

    func testUpdateScreenNameWithoutConfigureDoesNotThrow() {
        let crashReports = CrashReports()

        // Without configure, crashReporter is nil so customData is never set,
        // but the method should still not crash.
        XCTAssertNoThrow(crashReports.crashReportUpdateScreenName("Settings"))
    }

    // MARK: - Shared State Integration

    func testSharedStateSessionIdIsAccessible() {
        let crashReports = CrashReports()
        let mockState = MockLifecycleSharedState()
        mockState.sessionId = "lifecycle-session-456"

        crashReports.sharedState = mockState

        XCTAssertEqual(crashReports.sharedState?.sessionId, "lifecycle-session-456")
    }

    func testSharedStateAgentVersionIsAccessible() {
        let crashReports = CrashReports()
        let mockState = MockLifecycleSharedState()
        mockState.agentVersion = "2.5.0"

        crashReports.sharedState = mockState

        XCTAssertEqual(crashReports.sharedState?.agentVersion, "2.5.0")
    }

    func testSharedStateApplicationStateReturnsValue() {
        let crashReports = CrashReports()
        let mockState = MockLifecycleSharedState()

        crashReports.sharedState = mockState

        let appState = crashReports.sharedState?.applicationState(for: Date())
        XCTAssertEqual(appState, "foreground")
    }

    func testSharedStateNilByDefault() {
        let crashReports = CrashReports()

        XCTAssertNil(crashReports.sharedState)
    }
}


// MARK: - Test Support

final class MockLifecycleSharedState: AgentSharedState, @unchecked Sendable {
    var sessionId: String = "mock-session-id"
    var sessionMetadata: String?
    var agentVersion: String = "1.0.0"

    func applicationState(for _: Date) -> String? {
        "foreground"
    }
}
