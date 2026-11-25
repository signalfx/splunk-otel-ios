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

import CiscoLogger
import Foundation
import OpenTelemetryApi
import SplunkCommon

public struct CustomTrackingMetadata: ModuleEventMetadata {
    public var timestamp = Date()
}

public struct CustomTrackingData: ModuleEventData {
    public let name: String
    public let component: String

    /// The app's attributes, without the session attributes only the agent sets.
    ///
    /// The agent stamps the session itself, so an app value cannot move the event or error to
    /// another session, or give one that found no session an ID.
    public let attributes: [String: EventAttributeValue]

    public init(name: String, component: String, attributes: [String: EventAttributeValue]) {
        self.name = name
        self.component = component
        self.attributes = attributes.removingAgentOnlyAttributes()
    }
}


// MARK: - CustomTracking internal module

public final class CustomTrackingInternal {

    public static var instance = CustomTrackingInternal()


    // Shared state
    public unowned var sharedState: AgentSharedState?
    public var onPublishBlock: ((CustomTrackingMetadata, CustomTrackingData) -> Void)?

    package var isEnabled = true

    let diagnosticEnricher = ErrorDiagnosticEnricher()


    public required init() {}
}
