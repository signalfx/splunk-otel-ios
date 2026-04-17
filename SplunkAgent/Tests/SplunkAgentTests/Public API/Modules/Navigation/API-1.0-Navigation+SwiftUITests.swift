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

import SwiftUI
import XCTest

@testable import SplunkAgent

final class NavigationSwiftUITests: XCTestCase {

    func testTrackScreenModifierProducesView() {
        let view = Text("Hello")
            .trackScreen("TestScreen")

        XCTAssertNotNil(view)
    }

    func testTrackScreenModifierAcceptsDifferentViews() {
        let textView = Text("Screen A").trackScreen("ScreenA")
        let stackView = VStack { Text("Screen B") }.trackScreen("ScreenB")

        XCTAssertNotNil(textView)
        XCTAssertNotNil(stackView)
    }

    func testTrackScreenModifierAcceptsAttributes() {
        let attributes: [String: Any] = [
            "product.id": "A-1234",
            "product.category": "electronics"
        ]

        let view = Text("Hello")
            .trackScreen("TestScreen", attributes: attributes)

        XCTAssertNotNil(view)
    }

    func testTrackScreenModifierAcceptsNilAttributes() {
        let view = Text("Hello")
            .trackScreen("TestScreen", attributes: nil)

        XCTAssertNotNil(view)
    }
}
