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

import Foundation
internal import SplunkCommon

/// Session Start event. Sent when a session starts.
class SessionStartEvent: AgentEvent {

    // MARK: - Event Identification

    let domain = "mrum"
    let name = "session_start"
    let instrumentationScope = PackageIdentifier.default(named: "agent")
    let component = "session.start"


    // MARK: - Event properties

    var sessionID: String?
    var timestamp: Date?
    var attributes: [String: EventAttributeValue]?
    var body: EventAttributeValue?


    // MARK: - Initialization

    public init(sessionID: String, timestamp: Date, userID: String) {

        // Event properties
        self.sessionID = sessionID
        self.timestamp = timestamp

        attributes = [
            "enduser.anon_id": EventAttributeValue.string(userID)
        ]
    }
}
