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
@testable import SplunkCommon
@testable import SplunkCustomTracking

final class CustomEventTrackingTests: XCTestCase {
    private var module: CustomTrackingInternal!
    private var capturedData: CustomTrackingData?
    private var expectation: XCTestExpectation!

    override func setUp() {
        super.setUp()
        module = CustomTrackingInternal()
        expectation = XCTestExpectation(description: "onPublishBlock for event was called")

        module.onPublishBlock = { [weak self] _, data in
            self?.capturedData = data
            self?.expectation.fulfill()
        }
    }

    override func tearDown() {
        module = nil
        capturedData = nil
        expectation = nil
        super.tearDown()
    }

    func testTrackCustomEvent_withAttributes() throws {
        let eventName = "testCustomEventWithAttributes"
        let attributes: [String: EventAttributeValue] = [
            "userId": .string("testUser123"),
            "loginMethod": .string("biometrics"),
            "attempt": .int(1)
        ]
        let event = SplunkTrackableEvent(eventName: eventName, attributes: attributes)

        module.track(event)

        wait(for: [expectation], timeout: 1.0)

        let data = try XCTUnwrap(capturedData)
        XCTAssertEqual(data.name, eventName)
        XCTAssertEqual(data.component, "event")
        XCTAssertEqual(getStringValue(for: "userId", in: data), "testUser123")
        XCTAssertEqual(getStringValue(for: "loginMethod", in: data), "biometrics")
        XCTAssertEqual(getIntValue(for: "attempt", in: data), 1)
    }

    func testTrackCustomEvent_withoutAttributes() throws {
        let eventName = "testCustomEventWithoutAttributes"
        let event = SplunkTrackableEvent(eventName: eventName, attributes: [:])

        module.track(event)

        wait(for: [expectation], timeout: 1.0)

        let data = try XCTUnwrap(capturedData)
        XCTAssertEqual(data.name, eventName)
        XCTAssertEqual(data.component, "event")
        XCTAssertTrue(data.attributes.isEmpty, "Attributes dictionary should be empty")
    }
}
