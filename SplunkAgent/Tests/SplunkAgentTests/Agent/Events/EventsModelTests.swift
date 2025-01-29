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

@testable import SplunkAgent

import XCTest

final class EventsModelTests: XCTestCase {

    func testEventsModel() throws {
        let eventsModel = EventsModel(named: "eventsModelTests")
        eventsModel.clear()

        let sessionID = UUID().uuidString

        // Check if storage is clear
        XCTAssertFalse(eventsModel.isSessionStartSending(sessionID))
        XCTAssertFalse(eventsModel.isSessionStartSent(sessionID))

        // Test sending session start
        eventsModel.markSessionStartSending(sessionID)
        XCTAssertTrue(eventsModel.isSessionStartSending(sessionID))
        XCTAssertFalse(eventsModel.isSessionStartSent(sessionID))

        // Test sent session start
        eventsModel.markSessionStartSent(sessionID)
        XCTAssertFalse(eventsModel.isSessionStartSending(sessionID))
        XCTAssertTrue(eventsModel.isSessionStartSent(sessionID))

        // Test shallow clear
        eventsModel.clear(andSync: false)
        XCTAssertFalse(eventsModel.isSessionStartSent(sessionID))

        // Test load
        eventsModel.load()
        XCTAssertTrue(eventsModel.isSessionStartSent(sessionID))

        // Test full clear
        eventsModel.clear()
        eventsModel.load()
        XCTAssertFalse(eventsModel.isSessionStartSent(sessionID))

        // Test clipping
        eventsModel.markSessionStartSent(sessionID)
        XCTAssertTrue(eventsModel.isSessionStartSent(sessionID))

        var lastSessionID: String?

        for _ in 0 ... eventsModel.maxSentSessionStarts {
            let addedSessionID = UUID().uuidString
            lastSessionID = addedSessionID

            eventsModel.markSessionStartSent(addedSessionID)

            XCTAssertTrue(eventsModel.isSessionStartSent(addedSessionID))
        }

        let lastAddedSessionID = try XCTUnwrap(lastSessionID)
        XCTAssertTrue(eventsModel.isSessionStartSent(lastAddedSessionID))
        XCTAssertFalse(eventsModel.isSessionStartSent(sessionID))

        // One last sync and load test to check if all ids are stored
        eventsModel.sync()
        eventsModel.clear(andSync: false)
        eventsModel.load()
        XCTAssertTrue(eventsModel.sentSessionStartIDs.count == eventsModel.maxSentSessionStarts)
        XCTAssertTrue(eventsModel.isSessionStartSent(lastAddedSessionID))
        XCTAssertFalse(eventsModel.isSessionStartSent(sessionID))
    }
}
