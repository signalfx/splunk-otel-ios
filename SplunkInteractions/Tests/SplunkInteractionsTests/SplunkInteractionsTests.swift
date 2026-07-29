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
import XCTest

@_spi(SplunkInternal) @testable import SplunkInteractions

final class SplunkInteractionsTests: XCTestCase {

    func testInteractionTypeReturnsCorrectStrings() {
        let interactions = Interactions()

        let types: [(CiscoInteractions.InteractionType, String)] = [
            (.gestureTap, "tap"),
            (.gestureLongPress, "long_press"),
            (.gestureDoubleTap, "double_tap"),
            (.gesturePinch, "pinch"),
            (.gestureRotation, "rotation"),
            (.focus, "focus"),
            (.softKeyboard, "soft_keyboard")
        ]

        for (type, expected) in types {
            XCTAssertEqual(interactions.interactionType(from: type), expected)
        }
    }

    func testRageTapIsNotAnInteractionType() {
        let interactions = Interactions()
        XCTAssertNil(interactions.interactionType(from: .gestureRageTap))
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

    func testRageTapSendsFrustration() async {
        let destination = TestInteractionDestination()
        let interactions = Interactions(destination: destination)

        await interactions.handleEventType(.gestureRageTap, viewHierarchy: nil, targetElement: nil, time: Date())

        XCTAssertEqual(destination.didReceiveFrustrationCallCount, 1)
        XCTAssertEqual(destination.didReceiveInteractionCallCount, 0)
    }

    func testRageTapDoesNotSendInteraction() async {
        let destination = TestInteractionDestination()
        let interactions = Interactions(destination: destination)

        await interactions.handleEventType(.gestureRageTap, viewHierarchy: nil, targetElement: nil, time: Date())

        XCTAssertEqual(destination.didReceiveInteractionCallCount, 0)
    }

    func testOnActivityIsThreadSafeAcrossConcurrentReadsAndWrites() {
        // Regression test for the P1 race between the detector task reading
        // `onActivity` and the host-app install path writing it: the property
        // must be safely assignable while concurrently read.
        let interactions = Interactions()

        let readers = 4
        let writers = 4
        let iterations = 5_000

        let group = DispatchGroup()
        let readQueue = DispatchQueue(label: "test.reader", attributes: .concurrent)
        let writeQueue = DispatchQueue(label: "test.writer", attributes: .concurrent)

        for _ in 0 ..< readers {
            group.enter()
            readQueue.async {
                for _ in 0 ..< iterations {
                    _ = interactions.onActivity
                }
                group.leave()
            }
        }

        for _ in 0 ..< writers {
            group.enter()
            writeQueue.async {
                for idx in 0 ..< iterations {
                    interactions.onActivity = idx.isMultiple(of: 2) ? nil : { _ in }
                }
                group.leave()
            }
        }

        XCTAssertEqual(group.wait(timeout: .now() + 10), .success)
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
