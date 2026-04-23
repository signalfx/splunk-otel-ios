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
import SplunkNavigation
import XCTest

@testable import SplunkAgent

/// Typealias to disambiguate the SplunkAgent `NavigationConfiguration`
/// from `SplunkNavigation.NavigationConfiguration` in this test file.
private typealias AgentNavigationConfiguration = SplunkAgent.NavigationConfiguration

final class NavModuleConfigConversionTests: XCTestCase {

    // MARK: - Default values

    func testDefaultConfigConversion() {
        let config = AgentNavigationConfiguration()

        let result = config.asNavigationConfiguration

        XCTAssertTrue(result.isEnabled)
        XCTAssertNil(result.enableAutomatedTracking)
        XCTAssertNil(result.navigationEventProcessor)
    }

    // MARK: - Property forwarding

    func testIsEnabledForwarded() {
        let config = AgentNavigationConfiguration(isEnabled: false)

        let result = config.asNavigationConfiguration

        XCTAssertFalse(result.isEnabled)
    }

    func testEnableAutomatedTrackingForwarded() {
        let config = AgentNavigationConfiguration(enableAutomatedTracking: true)

        let result = config.asNavigationConfiguration

        XCTAssertEqual(result.enableAutomatedTracking, true)
    }

    // MARK: - Processor wrapping

    func testProcessorWrappedInAdapter() {
        let config = AgentNavigationConfiguration(
            navigationEventProcessor: PassthroughModuleProcessor()
        )

        let result = config.asNavigationConfiguration

        XCTAssertNotNil(result.navigationEventProcessor)
    }

    func testNilProcessorStaysNil() {
        let config = AgentNavigationConfiguration(navigationEventProcessor: nil)

        let result = config.asNavigationConfiguration

        XCTAssertNil(result.navigationEventProcessor)
    }

    func testWrappedProcessorForwardsCorrectly() {
        let config = AgentNavigationConfiguration(
            navigationEventProcessor: PassthroughModuleProcessor()
        )

        let result = config.asNavigationConfiguration
        let event = result.navigationEventProcessor?
            .onViewController(
                typeName: "TestVC",
                controllerIdentity: "123"
            )

        XCTAssertEqual(event?.name, "TestVC")
    }
}
