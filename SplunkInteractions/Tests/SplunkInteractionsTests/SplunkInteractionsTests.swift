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

import CiscoInteractions
import CiscoRuntimeCache
import CiscoSwizzling
import Foundation
@testable import SplunkInteractions
import XCTest

final class SplunkInteractionsTests: XCTestCase {

    func testInteractionTypeReturnsCorrectStrings() {
        let interactions = Interactions()

        let types: [(CiscoInteractions.InteractionType, String)] = [
            (.gestureTap, "tap"),
            (.gestureLongPress, "long_press"),
            (.gestureDoubleTap, "double_tap"),
            (.gestureRageTap, "rage_tap"),
            (.gesturePinch, "pinch"),
            (.gestureRotation, "rotation"),
            (.softKeyboard, "soft_keyboard")
        ]

        for (type, expected) in types {
            XCTAssertEqual(interactions.interactionType(from: type), expected)
        }
    }

    func testHandlingStream() {
        let interactions = Interactions()
        interactions.startInteractionsDetection()
        let expectation = XCTestExpectation(description: "Waiting for async task")


        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if interactions.interactionsDetector != nil {
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testHandlingEvents() {
        let destination = TestInteractionDestination()
        let interactions = Interactions(destination: destination)
        interactions.startInteractionsDetection()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NotificationCenter.default.post(
                name: UIApplication.keyboardWillHideNotification,
                object: nil
            )
        }

        let expectation = XCTestExpectation(description: "Waiting for async task")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if destination.didReceiveInteractionCallCount > 0, destination.actionName == "soft_keyboard" {
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1.0)
    }
}
