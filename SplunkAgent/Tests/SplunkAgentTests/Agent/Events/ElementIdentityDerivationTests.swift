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

import SplunkUICommon
import UIKit
import XCTest

final class ElementIdentityDerivationTests: XCTestCase {

    // MARK: - Swift type names

    func testSwiftViewControllerTypeNameIsStableAcrossInstances() {
        let firstTypeName = typeInspectorName(for: ElementIdentityViewController())
        let secondTypeName = typeInspectorName(for: ElementIdentityViewController())

        XCTAssertEqual(firstTypeName, secondTypeName)
        XCTAssertEqual(firstTypeName, "SplunkAgentTests.ElementIdentityViewController")
    }

    func testSwiftViewControllerElementNameDropsModulePrefix() {
        let typeName = typeInspectorName(for: ElementIdentityViewController())

        XCTAssertEqual(elementId(from: typeName), "SplunkAgentTests.ElementIdentityViewController")
        XCTAssertEqual(
            ClassNameSanitization.sanitize(typeName: typeName, bundleName: "SplunkAgentTests"),
            "ElementIdentityViewController"
        )
    }

    func testPrivateSwiftViewControllerFallsBackToStableBareClassName() {
        let typeName = typeInspectorName(for: PrivateElementIdentityViewController())

        XCTAssertEqual(elementId(from: typeName), "PrivateElementIdentityViewController")
        XCTAssertEqual(
            ClassNameSanitization.sanitize(typeName: typeName, bundleName: "SplunkAgentTests"),
            "PrivateElementIdentityViewController"
        )
    }

    // MARK: - Objective-C type names

    func testObjectiveCViewControllerTypeNameIsBareClassName() {
        let typeName = typeInspectorName(for: UINavigationController())

        XCTAssertEqual(elementId(from: typeName), "UINavigationController")
        XCTAssertEqual(
            ClassNameSanitization.sanitize(typeName: typeName, bundleName: "SplunkAgentTests"),
            "UINavigationController"
        )
    }


    // MARK: - Helpers

    private func typeInspectorName(for controller: UIViewController) -> String {
        let classType = type(of: controller)
        let typeName = NSStringFromClass(classType)

        if typeName.hasPrefix("_Tt") {
            return String(describing: classType)
        }

        return typeName
    }

    private func elementId(from rawTypeName: String) -> String {
        rawTypeName
    }
}

final class ElementIdentityViewController: UIViewController {}

private final class PrivateElementIdentityViewController: UIViewController {}
