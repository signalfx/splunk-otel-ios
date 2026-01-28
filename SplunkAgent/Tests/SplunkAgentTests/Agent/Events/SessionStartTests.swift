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
@testable import SplunkAgent
@testable import SplunkCommon

final class SessionStartTests: XCTestCase {

    func testSessionStartEvent() throws {
        let timestamp = Date()
        let sessionId = UUID().uuidString
        let previousSessionId = UUID().uuidString

        let event = SessionStartEvent(
            timestamp: timestamp,
            sessionId: sessionId,
            previousSessionId: previousSessionId
        )

        XCTAssertEqual(event.name, "session.start")
        XCTAssertEqual(event.timestamp, timestamp)
        XCTAssertEqual(event.sessionId, sessionId)

        let checkedPreviousId = try XCTUnwrap(event.attributes?["session.previous_id"]?.description)
        XCTAssertEqual(checkedPreviousId, previousSessionId)
    }
}
