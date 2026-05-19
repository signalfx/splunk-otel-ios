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

final class CrashReportsModuleTests: XCTestCase {

    // MARK: - CrashReportsMetadata

    func testMetadataDefaultEventName() {
        let metadata = CrashReportsMetadata()

        XCTAssertEqual(metadata.eventName, CrashReportConstants.moduleEventName)
    }

    func testMetadataTimestampIsRecentlyCreated() {
        let before = Date()
        let metadata = CrashReportsMetadata()
        let after = Date()

        XCTAssertGreaterThanOrEqual(metadata.timestamp, before)
        XCTAssertLessThanOrEqual(metadata.timestamp, after)
    }

    func testMetadataConformsToModuleEventMetadata() {
        // Compile-time conformance: this assignment fails to build if the protocol is not satisfied.
        let metadata: any ModuleEventMetadata = CrashReportsMetadata()

        XCTAssertNotNil(metadata.timestamp)
    }

    // MARK: - install

    func testInstallWithNilConfigDoesNotThrow() {
        let crashReports = CrashReports()

        XCTAssertNoThrow(crashReports.install(with: nil, remoteConfiguration: nil))
    }

    func testInstallWithEnabledConfigDoesNotThrow() {
        let crashReports = CrashReports()
        let config = CrashReportsConfiguration(isEnabled: true)

        XCTAssertNoThrow(crashReports.install(with: config, remoteConfiguration: nil))
    }

    func testInstallWithDisabledConfigDoesNotThrow() {
        let crashReports = CrashReports()
        let config = CrashReportsConfiguration(isEnabled: false)

        XCTAssertNoThrow(crashReports.install(with: config, remoteConfiguration: nil))
    }

    // MARK: - onPublish

    func testOnPublishSetsDataConsumer() {
        let crashReports = CrashReports()
        var callbackInvoked = false

        crashReports.onPublish { _, _ in
            callbackInvoked = true
        }

        XCTAssertNotNil(crashReports.crashReportDataConsumer)

        crashReports.crashReportDataConsumer?(CrashReportsMetadata(), "test-payload")
        XCTAssertTrue(callbackInvoked)
    }

    func testOnPublishReplacesExistingConsumer() {
        let crashReports = CrashReports()
        var firstCalled = false
        var secondCalled = false

        crashReports.onPublish { _, _ in
            firstCalled = true
        }
        crashReports.onPublish { _, _ in
            secondCalled = true
        }

        crashReports.crashReportDataConsumer?(CrashReportsMetadata(), "test")

        XCTAssertFalse(firstCalled)
        XCTAssertTrue(secondCalled)
    }

    func testOnPublishReceivesCorrectPayload() {
        let crashReports = CrashReports()
        var receivedPayload: String?

        crashReports.onPublish { _, payload in
            receivedPayload = payload
        }

        crashReports.crashReportDataConsumer?(CrashReportsMetadata(), "crash-data-json")

        XCTAssertEqual(receivedPayload, "crash-data-json")
    }

    // MARK: - deleteData

    func testDeleteDataDoesNotThrow() {
        let crashReports = CrashReports()
        let metadata = CrashReportsMetadata()

        XCTAssertNoThrow(crashReports.deleteData(for: metadata))
    }
}
