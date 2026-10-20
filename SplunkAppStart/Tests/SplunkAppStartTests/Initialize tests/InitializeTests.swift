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

@testable import SplunkAppStart

final class InitializeTests: XCTestCase {
    func testInitialize() throws {
        let processStart = Date(timeIntervalSinceReferenceDate: 1_000)
        let destination = DebugDestination()
        let initializeStart = processStart.addingTimeInterval(0.2)
        let initializeEnd = processStart.addingTimeInterval(0.4)
        let eventName = "test"
        let eventTimestamp = processStart.addingTimeInterval(0.3)

        let appStart = AppStart()
        appStart.processStartTimestamp = processStart
        appStart.destination = destination

        appStart.reportAgentInitialize(
            start: initializeStart,
            end: initializeEnd,
            events: [eventName: eventTimestamp],
            configurationSettings: [:]
        )
        appStart.process(
            event: .didFinishLaunching(
                processStart.addingTimeInterval(0.1),
                .foreground
            )
        )
        appStart.process(event: .didBecomeActive(processStart.addingTimeInterval(1)))

        // Check dates
        try checkDates(in: destination)

        let storedInitialize = try XCTUnwrap(destination.storedInitialize)

        // Check events
        let events = try XCTUnwrap(storedInitialize.events)
        XCTAssertTrue(!events.isEmpty)

        // Check test event
        let testEvent = try XCTUnwrap(events.first)
        XCTAssertTrue(testEvent.name == eventName)
        XCTAssertTrue(testEvent.timestamp == eventTimestamp)
    }

    func testInitializeOutsideCapturedAppStartIsDiscarded() throws {
        let processStart = Date(timeIntervalSinceReferenceDate: 2_000)
        let destination = DebugDestination()
        let appStart = AppStart()
        appStart.processStartTimestamp = processStart
        appStart.destination = destination

        appStart.reportAgentInitialize(
            start: processStart.addingTimeInterval(60 * 60),
            end: processStart.addingTimeInterval(60 * 60 + 1),
            events: [:],
            configurationSettings: [:]
        )
        appStart.process(
            event: .didFinishLaunching(
                processStart.addingTimeInterval(0.1),
                .foreground
            )
        )
        appStart.process(event: .didBecomeActive(processStart.addingTimeInterval(1)))

        let storedAppStart = try XCTUnwrap(destination.storedAppStart)
        XCTAssertEqual(storedAppStart.type, .cold)
        XCTAssertNil(destination.storedInitialize)
    }

    func testInitializeIsNotAttachedToWarmStart() throws {
        let processStart = Date(timeIntervalSinceReferenceDate: 3_000)
        let foreground = processStart.addingTimeInterval(60 * 60)
        let destination = DebugDestination()
        let appStart = AppStart()
        appStart.processStartTimestamp = processStart
        appStart.destination = destination

        appStart.reportAgentInitialize(
            start: processStart.addingTimeInterval(0.2),
            end: processStart.addingTimeInterval(0.4),
            events: [:],
            configurationSettings: [:]
        )
        appStart.process(
            event: .didFinishLaunching(
                processStart.addingTimeInterval(0.1),
                .background
            )
        )
        appStart.process(event: .willEnterForeground(foreground))
        appStart.process(event: .didBecomeActive(foreground.addingTimeInterval(0.5)))

        let storedAppStart = try XCTUnwrap(destination.storedAppStart)
        XCTAssertEqual(storedAppStart.type, .warm)
        XCTAssertNil(destination.storedInitialize)
    }

    func testInitializeWithEventOutsideChildIntervalIsDiscarded() throws {
        let processStart = Date(timeIntervalSinceReferenceDate: 4_000)
        let destination = DebugDestination()
        let appStart = AppStart()
        appStart.processStartTimestamp = processStart
        appStart.destination = destination

        appStart.reportAgentInitialize(
            start: processStart.addingTimeInterval(0.2),
            end: processStart.addingTimeInterval(0.4),
            events: ["late": processStart.addingTimeInterval(0.5)],
            configurationSettings: [:]
        )
        appStart.process(
            event: .didFinishLaunching(
                processStart.addingTimeInterval(0.1),
                .foreground
            )
        )
        appStart.process(event: .didBecomeActive(processStart.addingTimeInterval(1)))

        let storedAppStart = try XCTUnwrap(destination.storedAppStart)
        XCTAssertEqual(storedAppStart.type, .cold)
        XCTAssertNil(destination.storedInitialize)
    }
}
