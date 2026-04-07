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

final class CrashReportsRemoteConfigurationTests: XCTestCase {

    // MARK: - Helpers

    private func jsonData(enabled: Bool) -> Data {
        Data(#"{"configuration":{"mrum":{"crashReporting":{"enabled":\#(enabled)}}}}"#.utf8)
    }

    // MARK: - Valid JSON

    func testValidJSONWithEnabledTrue() throws {
        let config = try XCTUnwrap(CrashReportsRemoteConfiguration(from: jsonData(enabled: true)))

        XCTAssertTrue(config.enabled)
    }

    func testValidJSONWithEnabledFalse() throws {
        let config = try XCTUnwrap(CrashReportsRemoteConfiguration(from: jsonData(enabled: false)))

        XCTAssertFalse(config.enabled)
    }

    // MARK: - Invalid JSON

    func testEmptyDataReturnsNil() {
        let config = CrashReportsRemoteConfiguration(from: Data())

        XCTAssertNil(config)
    }

    func testMalformedJSONReturnsNil() {
        let data = Data("not valid json".utf8)

        let config = CrashReportsRemoteConfiguration(from: data)

        XCTAssertNil(config)
    }

    func testMissingConfigurationKeyReturnsNil() {
        let data = Data(#"{"other":{"mrum":{"crashReporting":{"enabled":true}}}}"#.utf8)

        let config = CrashReportsRemoteConfiguration(from: data)

        XCTAssertNil(config)
    }

    func testMissingMrumKeyReturnsNil() {
        let data = Data(#"{"configuration":{"other":{}}}"#.utf8)

        let config = CrashReportsRemoteConfiguration(from: data)

        XCTAssertNil(config)
    }

    func testMissingCrashReportingKeyReturnsNil() {
        let data = Data(#"{"configuration":{"mrum":{"other":{}}}}"#.utf8)

        let config = CrashReportsRemoteConfiguration(from: data)

        XCTAssertNil(config)
    }

    func testMissingEnabledFieldReturnsNil() {
        let data = Data(#"{"configuration":{"mrum":{"crashReporting":{}}}}"#.utf8)

        let config = CrashReportsRemoteConfiguration(from: data)

        XCTAssertNil(config)
    }

    func testWrongEnabledTypeReturnsNil() {
        let data = Data(#"{"configuration":{"mrum":{"crashReporting":{"enabled":"yes"}}}}"#.utf8)

        let config = CrashReportsRemoteConfiguration(from: data)

        XCTAssertNil(config)
    }

    func testExtraFieldsDoNotPreventParsing() throws {
        let data = Data(
            #"{"configuration":{"mrum":{"crashReporting":{"enabled":true,"extra":"ignored"},"other":{}},"extra":true}}"#.utf8
        )

        let config = try XCTUnwrap(CrashReportsRemoteConfiguration(from: data))

        XCTAssertTrue(config.enabled)
    }
}
