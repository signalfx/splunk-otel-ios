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

/// Session start event.
///
/// Session start event is sent at each session's start. It optionally contains information  about a previous session
/// in case the new session follows the previous session.
struct SessionStartEvent: AgentEvent {

    // MARK: - Event Identification

    let domain = "mrum"
    let name = "session.start"
    let instrumentationScope = PackageIdentifier.default(named: "agent")
    let component = "agent"


    // MARK: - Event properties

    var sessionId: String?
    var timestamp: Date?
    var attributes: [String: EventAttributeValue]?
    var body: EventAttributeValue?


    // MARK: - Initialization

    /// Initializes Session start event.
    ///
    /// - Parameters:
    ///   - timestamp: Session start timestamp.
    ///   - sessionId: A session id of the started session.
    ///   - previousSessionId: An optional previous session's id. Sent when the new session follows up the previous session.
    init(timestamp: Date, sessionId: String, previousSessionId: String?) {
        self.timestamp = timestamp
        self.sessionId = sessionId

        // Add optional previous session id
        if let previousSessionId {
            attributes = [
                "session.previous_id": .string(previousSessionId)
            ]
        }
    }
}
