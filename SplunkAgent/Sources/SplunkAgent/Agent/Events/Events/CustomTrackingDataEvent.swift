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
internal import SplunkSharedProtocols
internal import SplunkLogger
internal import SplunkCustomTrackingProxy

// MARK: - Custom Tracking data event

struct CustomTrackingDataEvent: AgentEvent {


    // MARK: - Properties

    let domain: String
    let name: String
    let instrumentationScope: String
    let component: String
    var sessionID: String?
    var timestamp: Date?
    var attributes: [String: SplunkSharedProtocols.EventAttributeValue]?
    var body: SplunkSharedProtocols.EventAttributeValue?

    private let internalLogger = InternalLogger(configuration: .agent(category: "CustomTrackingDataEvent"))


    // MARK: - Initialization

    init(metadata: CustomTrackingMetadata, data: CustomTrackingData, sessionID: String?) {
        domain = "data"
        name = data.name
        instrumentationScope = "com.splunk.rum.customtracking"
        component = "custom_tracking"
        self.sessionID = sessionID
        timestamp = metadata.timestamp
        attributes = data.attributes
        body = nil
        if sessionID == nil {
            internalLogger.log(level: .warn) {
                "sessionID is nil for CustomTrackingDataEvent"
            }
        }
    }
}
