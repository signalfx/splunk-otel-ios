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

@testable import SplunkAgent

/// Typealias to disambiguate the SplunkAgent `NavigationConfiguration`
/// from `SplunkNavigation.NavigationConfiguration` in this test file.
private typealias AgentNavigationConfiguration = SplunkAgent.NavigationConfiguration

/// Verifies that the CodingKeys exclusion on ``NavigationConfiguration``
/// serialises only the encodable fields and never exposes the processor.
final class NavConfigEncodingTests: XCTestCase {

    private func encode(_ config: AgentNavigationConfiguration) throws -> [String: Any] {
        let data = try JSONEncoder().encode(config)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return try XCTUnwrap(json)
    }

    func testIsEnabledPresent() throws {
        let json = try encode(AgentNavigationConfiguration(isEnabled: true))
        XCTAssertNotNil(json["isEnabled"])
    }

    func testEnableAutomatedTrackingPresent() throws {
        let json = try encode(AgentNavigationConfiguration(enableAutomatedTracking: true))
        XCTAssertNotNil(json["enableAutomatedTracking"])
    }

    func testEnableAutomatedTrackingAbsentWhenNil() throws {
        let json = try encode(AgentNavigationConfiguration())
        XCTAssertNil(json["enableAutomatedTracking"])
    }

    func testProcessorKeyAbsent() throws {
        let json = try encode(
            AgentNavigationConfiguration(
                navigationEventProcessor: PassthroughModuleProcessor()
            )
        )
        XCTAssertNil(json["navigationEventProcessor"])
    }
}
