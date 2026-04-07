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

/// Tests for the `threadList(threads:)` method in `CrashReports+Threads.swift`.
///
/// `allThreadsFromCrashReport` and `convertStackFrames` require live
/// `PLCrashReport` / `PLCrashReportThreadInfo` / `PLCrashReportStackFrameInfo`
/// instances and cannot be unit-tested without real crash data.
final class CrashReportsThreadListTests: XCTestCase {

    private let crashReports = CrashReports()

    // MARK: - threadList

    func testThreadListEmptyInputProducesEmptyJSONArray() throws {
        let result = crashReports.threadList(threads: [])

        let data = try XCTUnwrap(result.data(using: .utf8))
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [Any])

        XCTAssertTrue(parsed.isEmpty)
    }

    func testThreadListCarriesStackFramesThrough() throws {
        let frames: [[String: Any]] = [
            ["instructionPointer": 12_345, "imageName": "TestImage"],
            ["instructionPointer": 67_890, "imageName": "OtherImage"]
        ]
        let threads: [[CrashReportKeys: Any]] = [
            [.stackFrames: frames]
        ]

        let result = crashReports.threadList(threads: threads)

        let data = try XCTUnwrap(result.data(using: .utf8))
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])

        XCTAssertEqual(parsed.count, 1)

        let outputFrames = try XCTUnwrap(parsed[0]["stackFrames"] as? [[String: Any]])
        XCTAssertEqual(outputFrames.count, 2)
        XCTAssertEqual(outputFrames[0]["imageName"] as? String, "TestImage")
        XCTAssertEqual(outputFrames[1]["imageName"] as? String, "OtherImage")
    }

    func testThreadListWithoutDetailsOmitsThreadMetadata() throws {
        let threads: [[CrashReportKeys: Any]] = [
            [.stackFrames: [[String: Any]]()]
        ]

        let result = crashReports.threadList(threads: threads)

        let data = try XCTUnwrap(result.data(using: .utf8))
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])

        XCTAssertEqual(parsed.count, 1)
        XCTAssertNil(parsed[0]["threadNumber"])
        XCTAssertNil(parsed[0]["crashed"])
    }

    func testThreadListMultipleThreads() throws {
        let threads: [[CrashReportKeys: Any]] = [
            [.stackFrames: [["ip": 1]]],
            [.stackFrames: [["ip": 2]]],
            [.stackFrames: [["ip": 3]]]
        ]

        let result = crashReports.threadList(threads: threads)

        let data = try XCTUnwrap(result.data(using: .utf8))
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])

        XCTAssertEqual(parsed.count, 3)
    }

    func testThreadListWithNilStackFrames() throws {
        let threads: [[CrashReportKeys: Any]] = [
            [:] // No stackFrames key
        ]

        let result = crashReports.threadList(threads: threads)

        let data = try XCTUnwrap(result.data(using: .utf8))
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])

        XCTAssertEqual(parsed.count, 1)
    }
}
