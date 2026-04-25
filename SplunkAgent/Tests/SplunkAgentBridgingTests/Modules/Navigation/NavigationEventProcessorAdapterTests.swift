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

@testable import SplunkAgentObjC

/// Verifies that ``NavigationEventProcessorAdapter`` correctly bridges
/// an ObjC ``NavigationEventProcessorObjC`` implementation into the internal
/// ``SplunkNavigation/NavigationEventProcessor`` protocol, including name
/// passthrough, event suppression, attribute forwarding, and non-string key
/// filtering.
final class NavigationEventProcessorAdapterTests: XCTestCase {

    // MARK: - Passthrough

    func testPassthroughName() {
        let adapter = NavigationEventProcessorAdapter(wrapping: PassthroughProcessorObjC())

        let event = adapter.onViewController(typeName: "HomeViewController", controllerIdentity: "12345")

        XCTAssertNotNil(event)
        XCTAssertEqual(event?.name, "HomeViewController")
        XCTAssertNil(event?.attributes)
    }


    // MARK: - Suppression

    func testSuppression() {
        let adapter = NavigationEventProcessorAdapter(wrapping: SuppressingProcessorObjC())

        let event = adapter.onViewController(typeName: "SomeController", controllerIdentity: "99999")

        XCTAssertNil(event)
    }


    // MARK: - Attributes passthrough

    func testStringAttributes() {
        let attributes: NSDictionary = ["app.section": "settings", "app.feature": "profile"]
        let adapter = NavigationEventProcessorAdapter(wrapping: AttributeProcessorObjC(attributes: attributes))

        let event = adapter.onViewController(typeName: "SettingsVC", controllerIdentity: "111")

        XCTAssertNotNil(event)
        XCTAssertEqual(event?.attributes?["app.section"] as? String, "settings")
        XCTAssertEqual(event?.attributes?["app.feature"] as? String, "profile")
    }

    func testNilAttributes() {
        let adapter = NavigationEventProcessorAdapter(wrapping: AttributeProcessorObjC(attributes: nil))

        let event = adapter.onViewController(typeName: "PlainVC", controllerIdentity: "222")

        XCTAssertNotNil(event)
        XCTAssertNil(event?.attributes)
    }


    // MARK: - Non-String key filtering

    func testNonStringKeysAreFiltered() {
        let attributes: NSDictionary = [
            "valid.key": "value",
            NSNumber(value: 42): "number-keyed"
        ]
        let adapter = NavigationEventProcessorAdapter(wrapping: AttributeProcessorObjC(attributes: attributes))

        let event = adapter.onViewController(typeName: "MixedVC", controllerIdentity: "333")

        XCTAssertNotNil(event)
        XCTAssertEqual(event?.attributes?.count, 1)
        XCTAssertEqual(event?.attributes?["valid.key"] as? String, "value")
    }

    func testAllNonStringKeysProducesNilAttributes() {
        let attributes: NSDictionary = [
            NSNumber(value: 1): "a",
            NSNumber(value: 2): "b"
        ]
        let adapter = NavigationEventProcessorAdapter(wrapping: AttributeProcessorObjC(attributes: attributes))

        let event = adapter.onViewController(typeName: "BadKeysVC", controllerIdentity: "444")

        XCTAssertNotNil(event)
        XCTAssertNil(event?.attributes)
    }


    // MARK: - Empty dictionary behavior

    func testEmptyDictionaryProducesNilAttributes() {
        let attributes: NSDictionary = [:]
        let adapter = NavigationEventProcessorAdapter(wrapping: AttributeProcessorObjC(attributes: attributes))

        let event = adapter.onViewController(typeName: "EmptyAttrsVC", controllerIdentity: "555")

        XCTAssertNotNil(event)
        XCTAssertNil(event?.attributes)
    }
}
