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

final class CrashReportsJSONTests: XCTestCase {

    private var crashReports: CrashReports!

    override func setUp() {
        super.setUp()
        crashReports = CrashReports()
    }

    override func tearDown() {
        crashReports = nil
        super.tearDown()
    }

    // MARK: - normalizeToJSONReady

    func testNormalizeFlatCrashReportKeysDict() throws {
        let input: [CrashReportKeys: Any] = [
            .signalName: "SIGABRT",
            .faultAddress: "0x1234"
        ]

        let result = try XCTUnwrap(crashReports.normalizeToJSONReady(input) as? [String: Any])

        XCTAssertEqual(result["signalName"] as? String, "SIGABRT")
        XCTAssertEqual(result["crash.address"] as? String, "0x1234")
    }

    func testNormalizeArrayOfCrashReportKeysDicts() throws {
        let input: [[CrashReportKeys: Any]] = [
            [.threadNumber: 0, .isCrashedThread: true],
            [.threadNumber: 1, .isCrashedThread: false]
        ]

        let result = try XCTUnwrap(crashReports.normalizeToJSONReady(input) as? [[String: Any]])

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0]["threadNumber"] as? Int, 0)
        XCTAssertEqual(result[0]["crashed"] as? Bool, true)
        XCTAssertEqual(result[1]["threadNumber"] as? Int, 1)
        XCTAssertEqual(result[1]["crashed"] as? Bool, false)
    }

    func testNormalizeNestedCrashReportKeysDict() throws {
        let inner: [CrashReportKeys: Any] = [.imageName: "libTest.dylib"]
        let outer: [CrashReportKeys: Any] = [.details: inner]

        let result = try XCTUnwrap(crashReports.normalizeToJSONReady(outer) as? [String: Any])
        let nestedResult = try XCTUnwrap(result["details"] as? [String: Any])

        XCTAssertEqual(nestedResult["imageName"] as? String, "libTest.dylib")
    }

    func testNormalizePrimitiveValuesPassThrough() {
        XCTAssertEqual(crashReports.normalizeToJSONReady("hello") as? String, "hello")
        XCTAssertEqual(crashReports.normalizeToJSONReady(42) as? Int, 42)
        XCTAssertEqual(crashReports.normalizeToJSONReady(true) as? Bool, true)
        XCTAssertEqual(crashReports.normalizeToJSONReady(3.14) as? Double, 3.14)
    }

    func testNormalizeEmptyDict() throws {
        let input: [CrashReportKeys: Any] = [:]

        let result = try XCTUnwrap(crashReports.normalizeToJSONReady(input) as? [String: Any])

        XCTAssertTrue(result.isEmpty)
    }

    func testNormalizeEmptyArray() throws {
        let input: [[CrashReportKeys: Any]] = []

        let result = try XCTUnwrap(crashReports.normalizeToJSONReady(input) as? [[String: Any]])

        XCTAssertTrue(result.isEmpty)
    }

    func testNormalizeDepthLimitPreventsRunawayRecursion() {
        var current: Any = "leaf"
        for _ in 0..<15 {
            current = [CrashReportKeys.details: current]
        }

        // At depth >= 10, the value is returned without further normalization.
        // This must not crash or hang.
        let result = crashReports.normalizeToJSONReady(current)
        XCTAssertNotNil(result)
    }

    func testNormalizeMixedValueTypes() throws {
        let input: [CrashReportKeys: Any] = [
            .signalName: "SIGSEGV",
            .error: true,
            .threadNumber: 3,
            .faultAddress: "0xDEAD"
        ]

        let result = try XCTUnwrap(crashReports.normalizeToJSONReady(input) as? [String: Any])

        XCTAssertEqual(result["signalName"] as? String, "SIGSEGV")
        XCTAssertEqual(result["error"] as? Bool, true)
        XCTAssertEqual(result["threadNumber"] as? Int, 3)
        XCTAssertEqual(result["crash.address"] as? String, "0xDEAD")
    }

    // MARK: - convertToJSONString

    func testConvertValidDictProducesValidJSON() throws {
        let input: [String: Any] = ["key": "value", "number": 42]

        let jsonString = try XCTUnwrap(crashReports.convertToJSONString(input))
        let data = try XCTUnwrap(jsonString.data(using: .utf8))
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(parsed["key"] as? String, "value")
        XCTAssertEqual(parsed["number"] as? Int, 42)
    }

    func testConvertEmptyArrayProducesValidJSON() throws {
        let input: [Any] = []

        let jsonString = try XCTUnwrap(crashReports.convertToJSONString(input))
        let data = try XCTUnwrap(jsonString.data(using: .utf8))
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [Any])

        XCTAssertTrue(parsed.isEmpty)
    }

    func testConvertCrashReportKeysDictNormalizesKeys() throws {
        let input: [CrashReportKeys: Any] = [
            .signalName: "SIGABRT",
            .error: true
        ]

        let jsonString = try XCTUnwrap(crashReports.convertToJSONString(input))
        let data = try XCTUnwrap(jsonString.data(using: .utf8))
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(parsed["signalName"] as? String, "SIGABRT")
        XCTAssertEqual(parsed["error"] as? Bool, true)
    }

    func testConvertArrayOfCrashReportKeysDicts() throws {
        let input: [[CrashReportKeys: Any]] = [
            [.threadNumber: 0, .isCrashedThread: true],
            [.threadNumber: 1, .isCrashedThread: false]
        ]

        let jsonString = try XCTUnwrap(crashReports.convertToJSONString(input))
        let data = try XCTUnwrap(jsonString.data(using: .utf8))
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])

        XCTAssertEqual(parsed.count, 2)
        XCTAssertEqual(parsed[0]["threadNumber"] as? Int, 0)
    }

    func testConvertUsesPrettyPrinting() throws {
        let input: [String: Any] = ["key": "value"]

        let jsonString = try XCTUnwrap(crashReports.convertToJSONString(input))

        XCTAssertTrue(jsonString.contains("\n"), "Pretty-printed JSON should contain newlines")
    }
}
