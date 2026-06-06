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
import XCTest

final class ControllerNameFilteringTests: XCTestCase {

    // MARK: - Exact matches

    func testShouldIgnoreUIKitInternalControllers() {
        XCTAssertTrue(ControllerNameFiltering.shouldIgnore(controllerTypeName: "UINavigationController"))
        XCTAssertTrue(ControllerNameFiltering.shouldIgnore(controllerTypeName: "UITabBarController"))
        XCTAssertTrue(ControllerNameFiltering.shouldIgnore(controllerTypeName: "UIInputWindowController"))
        XCTAssertTrue(ControllerNameFiltering.shouldIgnore(controllerTypeName: "UISystemKeyboardDockController"))
        XCTAssertTrue(ControllerNameFiltering.shouldIgnore(controllerTypeName: "UITrackingElementWindowController"))
        XCTAssertTrue(ControllerNameFiltering.shouldIgnore(controllerTypeName: "UIEditingOverlayViewController"))
    }

    func testShouldIgnoreSwiftUINavigationInfrastructure() {
        XCTAssertTrue(ControllerNameFiltering.shouldIgnore(controllerTypeName: "SwiftUI.UIKitNavigationController"))
        XCTAssertTrue(ControllerNameFiltering.shouldIgnore(controllerTypeName: "SwiftUI.UIKitTabBarController"))
        XCTAssertTrue(ControllerNameFiltering.shouldIgnore(controllerTypeName: "SwiftUI.UIKitSplitViewController"))
        XCTAssertTrue(ControllerNameFiltering.shouldIgnore(controllerTypeName: "SwiftUI.TabHostingController"))
        XCTAssertTrue(ControllerNameFiltering.shouldIgnore(controllerTypeName: "SwiftUI.NotifyingMulticolumnSplitViewController"))
        XCTAssertTrue(ControllerNameFiltering.shouldIgnore(controllerTypeName: "SwiftUI.PlatformAlertController"))
    }


    // MARK: - Prefix matches

    func testShouldIgnoreSwiftUIHostingController() {
        let name = "UIHostingController<ModifiedContent<DemoView, _TraitWritingModifier<AutomaticNavigationSource>>>"
        XCTAssertTrue(ControllerNameFiltering.shouldIgnore(controllerTypeName: name))
    }

    func testShouldIgnoreNavigationStackHostingController() {
        XCTAssertTrue(ControllerNameFiltering.shouldIgnore(controllerTypeName: "NavigationStackHostingController<AnyView>"))
    }

    func testShouldIgnorePresentationHostingController() {
        XCTAssertTrue(ControllerNameFiltering.shouldIgnore(controllerTypeName: "PresentationHostingController<AnyView>"))
    }

    func testShouldIgnoreSplitViewPrefix() {
        let name = "StyleContextSplitViewNavigationController<MergedStyle>"
        XCTAssertTrue(ControllerNameFiltering.shouldIgnore(controllerTypeName: name))
    }


    // MARK: - Pass-through names

    func testShouldNotIgnoreRegularController() {
        XCTAssertFalse(ControllerNameFiltering.shouldIgnore(controllerTypeName: "ProductDetailsViewController"))
    }

    func testShouldNotIgnoreSimilarPrefix() {
        let name = "UIHostingWrapperViewController"
        XCTAssertFalse(ControllerNameFiltering.shouldIgnore(controllerTypeName: name))
    }

    func testShouldNotIgnoreAppControllers() {
        XCTAssertFalse(ControllerNameFiltering.shouldIgnore(controllerTypeName: "SettingsViewController"))
        XCTAssertFalse(ControllerNameFiltering.shouldIgnore(controllerTypeName: "DetailViewController"))
    }
}
