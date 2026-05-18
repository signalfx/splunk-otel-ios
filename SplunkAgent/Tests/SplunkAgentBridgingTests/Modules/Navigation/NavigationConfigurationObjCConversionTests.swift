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

@testable import SplunkAgentObjC

/// Verifies that ``NavigationConfigurationObjC`` correctly converts into
/// ``SplunkNavigation/NavigationConfiguration``, including property forwarding,
/// processor routing, and end-to-end translation through the
/// ObjC → internal-protocol adapter.
final class NavConfigObjCConversionTests: XCTestCase {

    // MARK: - Helpers

    private func convert(_ config: NavigationConfigurationObjC) -> NavigationConfiguration? {
        config.moduleConfiguration as? NavigationConfiguration
    }


    // MARK: - Default values

    func testDefaultConfigConverts() {
        let config = NavigationConfigurationObjC()

        let result = convert(config)

        XCTAssertNotNil(result)
    }


    // MARK: - Property forwarding

    func testIsEnabledForwarded() {
        let config = NavigationConfigurationObjC(isEnabled: false, enableAutomatedTracking: false)

        let result = convert(config)

        XCTAssertEqual(result?.isEnabled, false)
    }

    func testEnableAutomatedTrackingForwarded() {
        let config = NavigationConfigurationObjC(
            isEnabled: true,
            enableAutomatedTracking: true
        )

        let result = convert(config)

        XCTAssertEqual(result?.enableAutomatedTracking, true)
    }


    // MARK: - Processor wrapping

    func testProcessorWrappedInAdapter() {
        let config = NavigationConfigurationObjC(
            isEnabled: true,
            enableAutomatedTracking: false,
            navigationEventProcessor: PassthroughProcessorObjC()
        )

        let result = convert(config)

        XCTAssertNotNil(result?.navigationEventProcessor)
    }

    func testNilProcessorStaysNil() {
        let config = NavigationConfigurationObjC()

        let result = convert(config)

        XCTAssertNil(result?.navigationEventProcessor)
    }

    func testWrappedProcessorForwardsCorrectly() {
        let config = NavigationConfigurationObjC(
            isEnabled: true,
            enableAutomatedTracking: false,
            navigationEventProcessor: PassthroughProcessorObjC()
        )

        let result = convert(config)
        let event = result?.navigationEventProcessor?
            .onViewController(
                typeName: "TestVC",
                controllerIdentity: "123"
            )

        XCTAssertEqual(event?.name, "TestVC")
    }


    // MARK: - End-to-end ObjC → internal chain

    /// Exercises the full ObjC → NavEventProcessorObjCToInternalAdapter path.
    ///
    /// Asserts each processor contract (rename, enrich, suppress) survives
    /// the single adapter hop.
    func testEndToEndChain_rename() {
        let config = NavigationConfigurationObjC(
            isEnabled: true,
            enableAutomatedTracking: false,
            navigationEventProcessor: PassthroughProcessorObjC()
        )

        let internalConfig = convert(config)
        let event = internalConfig?.navigationEventProcessor?
            .onViewController(typeName: "HomeVC", controllerIdentity: "1")

        XCTAssertEqual(event?.name, "HomeVC")
    }

    func testEndToEndChain_enrich() {
        let attributes: NSDictionary = ["app.section": "settings"]
        let config = NavigationConfigurationObjC(
            isEnabled: true,
            enableAutomatedTracking: false,
            navigationEventProcessor: AttributeProcessorObjC(attributes: attributes)
        )

        let internalConfig = convert(config)
        let event = internalConfig?.navigationEventProcessor?
            .onViewController(typeName: "SettingsVC", controllerIdentity: "2")

        XCTAssertEqual(event?.attributes?["app.section"] as? String, "settings")
    }

    func testEndToEndChain_suppress() {
        let config = NavigationConfigurationObjC(
            isEnabled: true,
            enableAutomatedTracking: false,
            navigationEventProcessor: SuppressingProcessorObjC()
        )

        let internalConfig = convert(config)
        let event = internalConfig?.navigationEventProcessor?
            .onViewController(typeName: "AnyVC", controllerIdentity: "3")

        XCTAssertNil(event)
    }
}
