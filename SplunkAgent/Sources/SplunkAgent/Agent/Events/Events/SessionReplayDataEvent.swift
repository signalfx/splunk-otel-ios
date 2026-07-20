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
    ///   - userActivity: Unix-millisecond timestamps of user interactions recorded during this segment.
    init(metadata: Metadata, data: Data, index: Int, sessionId: String?, scriptInstanceId: String, userActivity: [Int] = []) {
        // Event properties
        timestamp = metadata.timestamp
        body = EventAttributeValue(data)

        if let sessionId {
            self.sessionId = sessionId
        }


        // Event attributes
        attributes = [
            // Chunk metadata
            "segmentMetadata": .string(metadataToJSONString(metadata, userActivity: userActivity)),

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

    private func metadataToJSONString(_ metadata: Metadata, userActivity: [Int]) -> String {
        // We always prefer conversion with a standard encoder ...
        guard
            let metadataContent = try? JSONEncoder().encode(metadata),
            var jsonObject = try? JSONSerialization.jsonObject(with: metadataContent) as? [String: Any]
        else {
            // ... but if something fails, we can build it manually
            return fallbackJSON(metadata: metadata, userActivity: userActivity)
        }

        jsonObject["userActivity"] = userActivity

        guard
            let enrichedData = try? JSONSerialization.data(withJSONObject: jsonObject),
            let jsonString = String(data: enrichedData, encoding: .utf8)
        else {
            return fallbackJSON(metadata: metadata, userActivity: userActivity)
        }

        return jsonString
    }

    private func fallbackJSON(metadata: Metadata, userActivity: [Int]) -> String {
        let dict: [String: Any] = [
            "startUnixMs": metadata.startUnixMs,
            "endUnixMs": metadata.endUnixMs,
            "source": metadata.source,
            "userActivity": userActivity
        ]
        guard
            let data = try? JSONSerialization.data(withJSONObject: dict),
            let jsonString = String(data: data, encoding: .utf8)
        else {
            let activityJSON = userActivity.map(String.init).joined(separator: ",")
            let src = metadata.source
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            let start = metadata.startUnixMs
            let end = metadata.endUnixMs
            // swiftlint:disable:next line_length
            return "{\"startUnixMs\":\(start),\"endUnixMs\":\(end),\"source\":\"\(src)\",\"userActivity\":[\(activityJSON)]}"
        }

        return jsonString
    }
}
