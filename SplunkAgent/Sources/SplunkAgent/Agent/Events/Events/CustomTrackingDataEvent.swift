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

internal import CiscoLogger
import Foundation
internal import SplunkCommon
internal import SplunkCustomTracking

// MARK: - Custom Tracking data event

struct CustomTrackingDataEvent: AgentEvent {

    // MARK: - Properties

    let domain: String
    let name: String
    let instrumentationScope: String
    let component: String
    var sessionId: String?
    var timestamp: Date?
    var attributes: [String: SplunkCommon.EventAttributeValue]?
    var body: SplunkCommon.EventAttributeValue?

    private let internalLogger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "CustomTrackingDataEvent")


    // MARK: - Initialization

    init(metadata: CustomTrackingMetadata, data: CustomTrackingData, sessionId: String?) {
        domain = "data"
        name = data.name
        instrumentationScope = "com.splunk.rum.customtracking"
        component = data.component
        self.sessionId = sessionId
        timestamp = metadata.timestamp
        attributes = data.attributes

        body = nil
        if sessionId == nil {
            internalLogger.log(level: .warn) {
                "sessionId is nil for CustomTrackingDataEvent"
            }
        }
    }
}
