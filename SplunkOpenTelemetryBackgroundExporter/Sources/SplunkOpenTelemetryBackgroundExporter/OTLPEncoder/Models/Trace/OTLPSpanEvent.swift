//
/*
Copyright 2026 Splunk Inc.

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

// MARK: - OTLPSpanEvent

/// OTLP Span Event model.
///
/// A Span Event represents a timestamped annotation within a span. Events
/// are typically used to mark significant moments during the span's lifetime,
/// such as logging a message or recording an exception.
///
/// Based on OTLP specification v1.9.0.
/// See: https://github.com/open-telemetry/opentelemetry-proto/blob/v1.9.0/opentelemetry/proto/trace/v1/trace.proto
struct OTLPSpanEvent: Encodable {

    // MARK: - Properties

    /// Event timestamp in nanoseconds since Unix epoch (as decimal string).
    let timeUnixNano: OTLPUInt64

    /// The event name.
    let name: String

    /// Key-value pairs of event attributes.
    let attributes: [OTLPKeyValue]?

    /// The number of attributes that were dropped due to limits.
    let droppedAttributesCount: UInt32?


    // MARK: - Coding Keys

    private enum CodingKeys: String, CodingKey {
        case timeUnixNano
        case name
        case attributes
        case droppedAttributesCount
    }


    // MARK: - Initialization

    /// Creates a new span event.
    ///
    /// - Parameters:
    ///   - timeUnixNano: Event timestamp in nanoseconds.
    ///   - name: The event name.
    ///   - attributes: Event attributes.
    ///   - droppedAttributesCount: Number of dropped attributes.
    init(
        timeUnixNano: OTLPUInt64,
        name: String,
        attributes: [OTLPKeyValue]? = nil,
        droppedAttributesCount: UInt32? = nil
    ) {
        self.timeUnixNano = timeUnixNano
        self.name = name
        self.attributes = attributes
        self.droppedAttributesCount = droppedAttributesCount
    }


    // MARK: - Encodable

    /// Custom encoding to handle optional fields correctly.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: An error if encoding fails.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(timeUnixNano, forKey: .timeUnixNano)
        try container.encode(name, forKey: .name)

        if let attributes, !attributes.isEmpty {
            try container.encode(attributes, forKey: .attributes)
        }

        if let count = droppedAttributesCount, count > 0 {
            try container.encode(count, forKey: .droppedAttributesCount)
        }
    }
}
