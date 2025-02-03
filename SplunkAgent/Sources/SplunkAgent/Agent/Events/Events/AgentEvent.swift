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
@_implementationOnly import SplunkSharedProtocols

/// Base Event class. Holds base event data, attributes and metadata. Subclasses should fill in all necessary data and attributes.
class AgentEvent: Event {

    // MARK: - Event Identification

    /// Event domain, default value `mrum` for all mobile events.
    let domain: String = "mrum"

    /// Event name, default value `mobile_event`, subclasses should override.
    var name: String = "mobile_event"

    /// Instrumentation scope, defines a module from which the event was generated.
    /// Default value `com.splunk.rum`, subclasses can override.
    var instrumentationScope: String = "com.splunk.rum"


    // MARK: - Event Properties

    var sessionID: String?

    var timestamp: Date?

    var attributes: [String: EventAttributeValue]?

    var body: EventAttributeValue?


    // MARK: - Initialization

    init() {}
}

extension AgentEvent: Equatable {
    static func == (lhs: AgentEvent, rhs: AgentEvent) -> Bool {
        return
            lhs.domain == rhs.domain &&
            lhs.name == rhs.name &&
            lhs.instrumentationScope == rhs.instrumentationScope &&
            lhs.sessionID == rhs.sessionID &&
            lhs.timestamp == rhs.timestamp &&
            lhs.attributes == rhs.attributes &&
            lhs.body == rhs.body
    }
}
