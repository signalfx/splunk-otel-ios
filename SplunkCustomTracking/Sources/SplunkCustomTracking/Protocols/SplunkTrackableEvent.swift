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
import OpenTelemetryApi
import SplunkCommon


// MARK: - SplunkTrackableEvent Struct

/// A structure representing a custom, trackable event that can be reported to the agent.
///
/// Use this struct to define custom events with a specific name and a dictionary of associated attributes.
public struct SplunkTrackableEvent: SplunkTrackable {
    /// The date and time when the event was created or started.
    public var timestamp: Date
    /// An optional date and time marking the end of the event, used for calculating duration.
    public var timestampEnd: Date?
    /// A string that uniquely identifies the name of the event.
    public var eventName: String
    /// A dictionary of custom attributes that provide additional context about the event.
    public var attributes: [String: EventAttributeValue]

    // Simplified initializer for events
    /// Initializes a new trackable event with a given name and optional attributes.
    ///
    /// The event's `timestamp` is set to the current date and time upon initialization.
    ///
    /// ```swift
    /// // Create an event with a name and attributes
    /// let event = SplunkTrackableEvent(
    ///     eventName: "item-added-to-cart",
    ///     attributes: [
    ///         "item_id": .string("SKU-123"),
    ///         "quantity": .int(1)
    ///     ]
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - eventName: The name of the event.
    ///   - attributes: A dictionary of attributes to associate with the event. Defaults to an empty dictionary.
    public init(eventName: String, attributes: [String: EventAttributeValue] = [:]) {
        timestamp = Date()
        self.eventName = eventName
        self.attributes = attributes
    }

    /// Returns the event's attributes as a dictionary.
    ///
    /// This method conforms to the `SplunkTrackable` protocol by providing the dictionary of custom attributes
    /// associated with the event.
    /// - Returns: A dictionary of `[String: EventAttributeValue]`.
    public func toAttributesDictionary() -> [String: EventAttributeValue] {
        return attributes
    }
}
