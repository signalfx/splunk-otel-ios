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

/// Session replay refresh event.
///
/// Session replay refresh event is a custom Event that indicates the Session Replay is recording for the respective session.
struct SessionReplayRefreshEvent: AgentEvent {

    // MARK: - Event Identification

    let domain = "mrum"
    let name = "splunk.sessionReplay.isRecording"
    let instrumentationScope = PackageIdentifier.default(named: "agent")
    let component = "session.replay"


    // MARK: - Event properties

    var sessionId: String?
    var timestamp: Date?
    var attributes: [String: EventAttributeValue]?
    var body: EventAttributeValue?


    // MARK: - Initialization

    /// Initializes `SessionReplayRefreshEvent`event.
    ///
    /// - Parameters:
    ///   - timestamp: `SessionReplay` start timestamp.
    ///   - sessionId: The session id of the session where the a SessionReplay event was recorded.
    init(timestamp: Date, sessionId: String) {
        self.timestamp = timestamp
        self.sessionId = sessionId

        attributes = [
            "splunk.sessionReplay": .string("splunk")
        ]
    }
}
