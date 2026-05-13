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

    func testSwiftUIScreenTrackerDeduplicatesSameScreenAndAttributes() {
        let tracker = SwiftUIScreenTracker()
        var emitCount = 0

        tracker.trackIfChanged(screenName: "Home", attributes: ["tab": "main"]) {
            emitCount += 1
        }
        tracker.trackIfChanged(screenName: "Home", attributes: ["tab": "main"]) {
            emitCount += 1
        }

        XCTAssertEqual(emitCount, 1)
    }

    func testSwiftUIScreenTrackerEmitsWhenAttributesChange() {
        let tracker = SwiftUIScreenTracker()
        var emittedScreens: [String] = []

        tracker.trackIfChanged(screenName: "ProductDetail", attributes: ["product.id": "1"]) {
            emittedScreens.append("first")
        }
        tracker.trackIfChanged(screenName: "ProductDetail", attributes: ["product.id": "2"]) {
            emittedScreens.append("second")
        }

        XCTAssertEqual(emittedScreens, ["first", "second"])
    }

    func testSwiftUIScreenTrackerTreatsNilAndEmptyAttributesAsDuplicate() {
        let tracker = SwiftUIScreenTracker()
        var emitCount = 0

        tracker.trackIfChanged(screenName: "Home", attributes: nil) {
            emitCount += 1
        }
        tracker.trackIfChanged(screenName: "Home", attributes: [:]) {
            emitCount += 1
        }

        XCTAssertEqual(emitCount, 1)
    }

    func testSwiftUIScreenTrackerNormalizesMixedAnyArrays() {
        let tracker = SwiftUIScreenTracker()
        var emittedScreens: [String] = []

        let first: [Any] = ["a", 1, true]
        let duplicate: [Any] = ["a", 1, true]
        let changed: [Any] = ["a", 2, true]
        let firstAttributes: [String: Any] = ["items": first]
        let duplicateAttributes: [String: Any] = ["items": duplicate]
        let changedAttributes: [String: Any] = ["items": changed]

        tracker.trackIfChanged(screenName: "MixedArray", attributes: firstAttributes) {
            emittedScreens.append("first")
        }
        tracker.trackIfChanged(screenName: "MixedArray", attributes: duplicateAttributes) {
            emittedScreens.append("duplicate")
        }
        tracker.trackIfChanged(screenName: "MixedArray", attributes: changedAttributes) {
            emittedScreens.append("changed")
        }

        XCTAssertEqual(emittedScreens, ["first", "changed"])
    }
}
