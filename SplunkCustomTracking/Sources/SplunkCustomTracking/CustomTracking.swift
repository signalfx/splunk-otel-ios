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

/// Metadata associated with a custom tracking event, including the timestamp.
public struct CustomTrackingMetadata: ModuleEventMetadata {
    /// The date and time when the event occurred.
    public var timestamp = Date()
}

/// Represents the payload for a custom tracking event, including its name, component, and attributes.
public struct CustomTrackingData: ModuleEventData {
    /// The name of the custom event.
    public let name: String
    /// The component or category associated with the event (e.g., "event", "error").
    public let component: String
    /// A dictionary of attributes providing additional details about the event.
    public let attributes: [String: EventAttributeValue]

    /// Initializes the custom tracking data with the specified details.
    /// - Parameters:
    ///   - name: The name of the custom event.
    ///   - component: The component associated with the event.
    ///   - attributes: A dictionary of attributes for the event.
    public init(name: String, component: String, attributes: [String: EventAttributeValue]) {
        self.name = name
        self.component = component
        self.attributes = attributes
    }
}


// MARK: - CustomTracking internal module

/// The central class for handling custom event and error tracking.
///
/// This class manages the creation and publishing of custom tracking data. It acts as a module within the Splunk agent ecosystem.
public final class CustomTrackingInternal {

    /// A shared singleton instance of `CustomTrackingInternal` for global access.
    public static var instance = CustomTrackingInternal()


    // MARK: - Private Properties

    private let internalLogger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "LogCustomTracking")


    // Shared state
    /// A weak reference to the shared state of the agent, providing access to common configurations and resources.
    public unowned var sharedState: AgentSharedState?
    /// A closure that is called to publish custom tracking data.
    ///
    /// This block is set by the agent's core to handle the final emission of the event.
    public var onPublishBlock: ((CustomTrackingMetadata, CustomTrackingData) -> Void)?


    // Module conformance
    /// Initializes a new instance of the `CustomTrackingInternal` module.
    public required init() {}
}
