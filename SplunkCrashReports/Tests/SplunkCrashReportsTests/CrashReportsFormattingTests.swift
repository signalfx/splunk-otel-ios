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

@testable import SplunkCrashReports

/// Tests the custom-data serialization contract between `updateDeviceStats`
/// (which archives a `[String: String]` dictionary via `NSKeyedArchiver`) and
/// `addCustomData` (which unarchives it and maps keys to `CrashReportKeys`).
///
/// Direct testing of `addCustomData` and `formatCrashReport` requires a
/// `PLCrashReport` instance, which can only be constructed from real protobuf
/// crash data. These tests validate the archiving boundary independently.
final class CrashReportsFormattingTests: XCTestCase {

    // MARK: - Custom Data Serialization Contract

    func testCustomDataRoundTripPreservesAllFields() throws {
        let input: [String: String] = [
            "sessionId": "test-session-123",
            "battery": "85.0%",
            "disk": "50 GB",
            "memory": "2 GB",
            "screenName": "HomeScreen",
            "buildId": "42"
        ]

        let archived = try NSKeyedArchiver.archivedData(
            withRootObject: input,
            requiringSecureCoding: false
        )

        let unarchived = try XCTUnwrap(
            NSKeyedUnarchiver.unarchivedObject(
                ofClasses: [NSDictionary.self, NSString.self],
                from: archived
            ) as? [String: String]
        )

        XCTAssertEqual(unarchived["sessionId"], "test-session-123")
        XCTAssertEqual(unarchived["battery"], "85.0%")
        XCTAssertEqual(unarchived["disk"], "50 GB")
        XCTAssertEqual(unarchived["memory"], "2 GB")
        XCTAssertEqual(unarchived["screenName"], "HomeScreen")
        XCTAssertEqual(unarchived["buildId"], "42")
    }

    func testCustomDataRoundTripWithPartialFields() throws {
        let input: [String: String] = [
            "sessionId": "partial-session",
            "battery": "Unknown"
        ]

        let archived = try NSKeyedArchiver.archivedData(
            withRootObject: input,
            requiringSecureCoding: false
        )

        let unarchived = try XCTUnwrap(
            NSKeyedUnarchiver.unarchivedObject(
                ofClasses: [NSDictionary.self, NSString.self],
                from: archived
            ) as? [String: String]
        )

        XCTAssertEqual(unarchived["sessionId"], "partial-session")
        XCTAssertEqual(unarchived["battery"], "Unknown")
        XCTAssertNil(unarchived["disk"])
        XCTAssertNil(unarchived["memory"])
        XCTAssertNil(unarchived["screenName"])
        XCTAssertNil(unarchived["buildId"])
    }

    func testCustomDataRoundTripWithEmptyDictionary() throws {
        let input: [String: String] = [:]

        let archived = try NSKeyedArchiver.archivedData(
            withRootObject: input,
            requiringSecureCoding: false
        )

        let unarchived = try XCTUnwrap(
            NSKeyedUnarchiver.unarchivedObject(
                ofClasses: [NSDictionary.self, NSString.self],
                from: archived
            ) as? [String: String]
        )

        XCTAssertTrue(unarchived.isEmpty)
    }

}
