//
/*
Copyright 2024 Splunk Inc.

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
	
@testable import SplunkAppStart
import XCTest

final class InitializeTests: XCTestCase {
    func testInitialize() throws {
        let destination = DebugDestination()

        let initializeStart = Date()
        
        let eventName = "test"
        let eventTimestamp = Date()

        let appStart = AppStart()
        appStart.destination = destination

        appStart.startDetection()

        appStart.reportAgentInitialize(start: initializeStart, end: Date(), events: [eventName : eventTimestamp])

        simulateColdStartNotifications()

        // Check dates
        try checkDates(in: destination)

        let storedInitialize = try XCTUnwrap(destination.storedInitialize)

        // Check events
        let events = try XCTUnwrap(storedInitialize.events)
        XCTAssertTrue(events.count > 0)

        // Check test event
        let testEvent = try XCTUnwrap(events.first)
        XCTAssertTrue(testEvent.name == eventName)
        XCTAssertTrue(testEvent.timestamp == eventTimestamp)
    }
}
