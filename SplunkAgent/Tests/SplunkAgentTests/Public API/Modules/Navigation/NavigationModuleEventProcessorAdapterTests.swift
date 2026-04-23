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

final class NavModuleProcessorAdapterTests: XCTestCase {

    // MARK: - Passthrough

    func testPassthroughName() {
        let adapter = NavigationModuleEventProcessorAdapter(wrapping: PassthroughModuleProcessor())

        let event = adapter.onViewController(typeName: "HomeViewController", controllerIdentity: "12345")

        XCTAssertNotNil(event)
        XCTAssertEqual(event?.name, "HomeViewController")
        XCTAssertNil(event?.attributes)
    }

    // MARK: - Suppression

    func testSuppression() {
        let adapter = NavigationModuleEventProcessorAdapter(wrapping: SuppressingModuleProcessor())

        let event = adapter.onViewController(typeName: "SomeController", controllerIdentity: "99999")

        XCTAssertNil(event)
    }

    // MARK: - Attributes passthrough

    func testStringAttributes() {
        let attributes: [String: Any] = ["app.section": "settings", "app.feature": "profile"]
        let adapter = NavigationModuleEventProcessorAdapter(wrapping: AttributeModuleProcessor(attributes: attributes))

        let event = adapter.onViewController(typeName: "SettingsVC", controllerIdentity: "111")

        XCTAssertNotNil(event)
        XCTAssertEqual(event?.attributes?["app.section"] as? String, "settings")
        XCTAssertEqual(event?.attributes?["app.feature"] as? String, "profile")
    }

    func testNilAttributes() {
        let adapter = NavigationModuleEventProcessorAdapter(wrapping: AttributeModuleProcessor(attributes: nil))

        let event = adapter.onViewController(typeName: "PlainVC", controllerIdentity: "222")

        XCTAssertNotNil(event)
        XCTAssertNil(event?.attributes)
    }

    // MARK: - Parameter forwarding

    func testTypeNameForwarded() {
        let processor = CapturingModuleProcessor()
        let adapter = NavigationModuleEventProcessorAdapter(wrapping: processor)

        _ = adapter.onViewController(typeName: "DetailViewController", controllerIdentity: "42")

        XCTAssertEqual(processor.lastTypeName, "DetailViewController")
    }

    func testControllerIdentityForwarded() {
        let processor = CapturingModuleProcessor()
        let adapter = NavigationModuleEventProcessorAdapter(wrapping: processor)

        _ = adapter.onViewController(typeName: "AnyVC", controllerIdentity: "98765")

        XCTAssertEqual(processor.lastControllerIdentity, "98765")
    }
}
