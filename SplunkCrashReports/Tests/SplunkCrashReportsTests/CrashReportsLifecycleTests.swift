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
@_spi(SplunkInternal) @testable import SplunkCrashReports

/// Tests for `initializeCrashReporter`, `crashReportUpdateScreenName` and `appStateHandler`
/// in `CrashReports.swift`, and `refreshCachedSessionId` in `CrashReports+SessionId.swift`.
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

    func testInitializePreservesExistingExceptionHandler() {
        let previousHandler = NSGetUncaughtExceptionHandler()
        NSSetUncaughtExceptionHandler(testUncaughtExceptionHandler)

        defer {
            NSSetUncaughtExceptionHandler(previousHandler)
        }

        let crashReports = CrashReports()
        crashReports.configureCrashReporter()

        let result = crashReports.initializeCrashReporter()

        XCTAssertFalse(result)
        XCTAssertNotNil(NSGetUncaughtExceptionHandler())
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


    // MARK: - Cached session ID

    func testRefreshCachedSessionIdOnTheMainThreadStoresTheIdBeforeReturning() {
        let crashReports = CrashReports()
        let mockState = MockLifecycleSharedState()

        // Stands in for `initializeCrashReporter()`, which would enable a real crash handler.
        crashReports.configureCrashReporter()
        crashReports.isCrashReportingEnabled = true
        crashReports.sharedState = mockState

        let sessionIdKey = CrashReportCustomDataKeys.sessionId.rawValue

        mockState.sessionId = "first-session-id"
        crashReports.refreshCachedSessionId()
        XCTAssertEqual(customData(from: crashReports)?[sessionIdKey], "first-session-id")

        mockState.sessionId = "second-session-id"
        crashReports.refreshCachedSessionId()
        XCTAssertEqual(customData(from: crashReports)?[sessionIdKey], "second-session-id")
    }

    func testRefreshCachedSessionIdOffTheMainThreadReachesTheCrashReporter() {
        let crashReports = CrashReports()
        let mockState = MockLifecycleSharedState()
        mockState.sessionId = "background-session-id"

        crashReports.configureCrashReporter()
        crashReports.isCrashReportingEnabled = true
        crashReports.sharedState = mockState

        let refreshExpectation = expectation(description: "Refreshed on a background queue")
        DispatchQueue.global(qos: .utility)
            .async {
                crashReports.refreshCachedSessionId()
                refreshExpectation.fulfill()
            }
        wait(for: [refreshExpectation], timeout: arrivalTimeout)

        waitForCachedSessionId("background-session-id", in: crashReports)
    }

    func testRefreshCachedSessionIdWritesNothingWhileCrashReportingIsNotEnabled() {
        let crashReports = CrashReports()
        let mockState = MockLifecycleSharedState()
        mockState.sessionId = "unreported-session-id"

        // Configured but not enabled, as when the configuration turns crash reporting off.
        crashReports.configureCrashReporter()
        crashReports.sharedState = mockState

        crashReports.refreshCachedSessionId()
        drainMainQueue()

        XCTAssertNil(crashReports.crashReporter?.customData, "A crash reporter that is not enabled got custom data.")
    }

    func testQueuedDeviceStatsUpdateKeepsTheNewSessionId() throws {
        let crashReports = CrashReports()
        let mockState = MockLifecycleSharedState()
        mockState.sessionId = "previous-session-id"

        crashReports.configureCrashReporter()
        crashReports.isCrashReportingEnabled = true
        crashReports.sharedState = mockState

        // Queues a device stats update and waits until it has sampled the stats while the previous
        // session is current, so its write waits on the main queue.
        crashReports.crashReportUpdateScreenName("Home")
        crashReports.deviceDataQueue.sync {}

        let sessionIdKey = CrashReportCustomDataKeys.sessionId.rawValue
        mockState.sessionId = "current-session-id"
        crashReports.refreshCachedSessionId()
        XCTAssertEqual(customData(from: crashReports)?[sessionIdKey], "current-session-id")

        // Runs after every write queued on the main queue so far, including the device stats update.
        drainMainQueue()

        let cachedData = try XCTUnwrap(customData(from: crashReports))
        XCTAssertNotNil(cachedData[CrashReportCustomDataKeys.battery.rawValue], "The queued device stats update did not run.")
        XCTAssertEqual(cachedData[sessionIdKey], "current-session-id", "The queued update restored the previous session ID")
        XCTAssertEqual(cachedData[CrashReportCustomDataKeys.screenName.rawValue], "Home")
    }


    // MARK: - Helpers

    /// Timeout for something that must happen.
    ///
    /// The wait ends as soon as it happens, so a long limit costs nothing when the code works
    /// and tolerates a stalled test machine.
    private let arrivalTimeout: TimeInterval = 10

    /// Waits until the crash reporter's custom data holds the expected session ID.
    private func waitForCachedSessionId(_ sessionId: String, in crashReports: CrashReports) {
        let sessionIdKey = CrashReportCustomDataKeys.sessionId.rawValue
        let cachedExpectation = expectation(
            for: NSPredicate { _, _ in
                self.customData(from: crashReports)?[sessionIdKey] == sessionId
            },
            evaluatedWith: crashReports
        )
        wait(for: [cachedExpectation], timeout: arrivalTimeout)
    }

    /// Waits until the work queued on the main queue so far has run.
    private func drainMainQueue() {
        let drainExpectation = expectation(description: "Main queue drained")
        DispatchQueue.main.async {
            drainExpectation.fulfill()
        }
        wait(for: [drainExpectation], timeout: arrivalTimeout)
    }

    private func customData(from crashReports: CrashReports) -> [String: String]? {
        guard let data = crashReports.crashReporter?.customData else {
            return nil
        }

        return try? NSKeyedUnarchiver.unarchivedObject(
            ofClasses: [NSDictionary.self, NSString.self],
            from: data
        ) as? [String: String]
    }
}

private func testUncaughtExceptionHandler(_: NSException) {}


// MARK: - Test Support

final class MockLifecycleSharedState: AgentSharedState, @unchecked Sendable {
    var sessionId: String = "mock-session-id"
    var sessionMetadata: String?
    var agentVersion: String = "1.0.0"

    func applicationState(for _: Date) -> String? {
        "foreground"
    }
}
