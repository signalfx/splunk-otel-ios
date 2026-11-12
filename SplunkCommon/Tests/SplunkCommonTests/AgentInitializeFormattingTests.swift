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

import XCTest

@_spi(SplunkInternal) @testable import SplunkCommon

final class AgentInitializeFormattingTests: XCTestCase {

    func testEmptySettingsHaveNoValue() {
        XCTAssertNil(AgentInitializeFormatting.configurationSettings([:]))
    }

    func testOneSettingIsBracketed() {
        XCTAssertEqual(AgentInitializeFormatting.configurationSettings(["key": "value"]), "[key:value]")
    }

    func testTwoSettingsAreCommaSeparated() throws {
        let formatted = try XCTUnwrap(
            AgentInitializeFormatting.configurationSettings(["first": "1", "second": "2"])
        )

        XCTAssertTrue(formatted.hasPrefix("["))
        XCTAssertTrue(formatted.hasSuffix("]"))

        let entries = formatted.dropFirst().dropLast().components(separatedBy: ", ")
        XCTAssertEqual(Set(entries), ["first:1", "second:2"])
    }
}
