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

internal import CiscoSessionReplay
import Foundation
internal import SplunkCommon

/// Session Replay data event.
///
/// Sends session replay blob with metadata.
class SessionReplayDataEvent: AgentEvent {

    // MARK: - Event Identification

    let domain = "mrum"
    let name = "session_replay_data"
    let instrumentationScope = PackageIdentifier.default(named: "sessionreplay")
    let component = "session.replay"


    // MARK: - Event properties

    var sessionId: String?
    var timestamp: Date?
    var attributes: [String: EventAttributeValue]?
    var body: EventAttributeValue?


    // MARK: - Initialization

    /// Initializes Session Replay data event.
    ///
    /// - Parameters:
    ///   - metadata: `RecordMetadata` describing the session replay record.
    ///   - data: Session replay blob of type `Data`.
    ///   - index: Event sequence number within the session.
    ///   - sessionId: The `session Id` of a session in which the event occurred.
    ///               Optional so that we can see sessions with no session id in the backend.
    ///   - scriptInstanceId: Internal identifier used for backend purposes.
    init(metadata: Metadata, data: Data, index: Int, sessionId: String?, scriptInstanceId: String) {
        // Event properties
        timestamp = metadata.timestamp
        body = EventAttributeValue(data)

        if let sessionId {
            self.sessionId = sessionId
        }


        // Event attributes
        attributes = [
            // Chunk metadata
            "segmentMetadata": .string(metadataToJSONString(metadata)),

            // Script ID
            "splunk.scriptInstance": .string(scriptInstanceId),

            // Experimental attributes for integration PoC
            "rr-web.total-chunks": .double(1.0),
            "rr-web.chunk": .double(1.0),
            "rr-web.event": .int(index),
            "rr-web.offset": .double(Double(index))
        ]
    }


    // MARK: - Private methods

    private func metadataToJSONString(_ metadata: Metadata) -> String {
        // We always prefer conversion with a standard encoder ...
        guard
            let metadataContent = try? JSONEncoder().encode(metadata),
            let jsonString = String(data: metadataContent, encoding: .utf8)
        else {
            // ... but if something fails, we can build it manually
            return "{\"startUnixMs\":\(metadata.startUnixMs), \"endUnixMs\":\(metadata.endUnixMs), \"source\":\"\(metadata.source)\"}"
        }

        return jsonString
    }
}
