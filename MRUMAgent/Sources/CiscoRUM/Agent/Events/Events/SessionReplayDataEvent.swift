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

import Foundation
@_implementationOnly import CiscoSessionReplay
@_implementationOnly import MRUMSharedProtocols

/// Session Replay data events. Sends session replay blob with metadata.
class SessionReplayDataEvent: AgentEvent {

    // MARK: - Initialization

    /// Initializes Session Replay data event.
    ///
    /// - Parameters:
    ///   - metadata: `RecordMetadata` describing the session replay record.
    ///   - data: Session replay blob of type `Data`.
    ///   - sessionID: The `session ID` of a session in which the event occured. Optional so that we can see sessions with no session id in the backend.
    public init(metadata: Metadata, data: Data, sessionID: String?) {
        super.init()

        // Event identification
        name = "session_replay_data"
        instrumentationScope = "com.cisco.mrum.sessionreplay"

        // Event properties
        let timestamp = metadata.timestamp
        let startTimestamp = metadata.startUnixMs
        let endTimestamp = metadata.endUnixMs
        // let recordId = metadata.recordId

        if let sessionID {
            self.sessionID = sessionID
        }

        self.timestamp = timestamp
        body = EventAttributeValue(data)

        attributes = [
            "replay.start_timestamp": EventAttributeValue.int(startTimestamp),
            "replay.end_timestamp": EventAttributeValue.int(endTimestamp)
            // "replay.record_id": EventAttributeValue.string(recordId)
        ]
    }
}
