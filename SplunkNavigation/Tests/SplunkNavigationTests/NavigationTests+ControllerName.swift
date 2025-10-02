//
/*
Copyright 2025 Splunk Inc.

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

@testable import SplunkNavigation

#if canImport(SwiftUI)
    import SwiftUI
#endif
#if canImport(UIKit)
    import UIKit
#endif


final class NavigationControllerNameTests: XCTestCase {

    // MARK: - Private

    private let navigationModule = Navigation()

    #if canImport(SwiftUI)
        func testSwiftUIPreferredControllerName() throws {
            // Test UIHostingController
            let controllerName = navigationModule.preferredControllerName(
                for: UIHostingController(rootView: TestView())
            )
            XCTAssertEqual(controllerName, "UIHostingController<TestView>")
        }
    #endif

    #if canImport(UIKit)
        func testUIKitPreferredControllerName() throws {
            // Test UIViewController name
            let controllerName = navigationModule.preferredControllerName(for: UIViewController())
            XCTAssertEqual(controllerName, "UIViewController")
        }
    #endif
}
