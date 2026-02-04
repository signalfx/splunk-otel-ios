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


// MARK: - OTLPSpanLink

/// OTLP Span Link model.
///
/// A Span Link represents a causal relationship between spans in the same
/// or different traces. Links are commonly used to relate batch operations
/// to their individual item processing spans.
///
/// Based on OTLP specification v1.9.0.
/// See: https://github.com/open-telemetry/opentelemetry-proto/blob/v1.9.0/opentelemetry/proto/trace/v1/trace.proto
struct OTLPSpanLink: Encodable {

    // MARK: - Properties

    /// The trace ID of the linked span (lowercase hex string, 32 characters).
    let traceId: OTLPTraceId

    /// The span ID of the linked span (lowercase hex string, 16 characters).
    let spanId: OTLPSpanId

    /// The W3C tracestate header value of the linked span.
    let traceState: String?

    /// Key-value pairs of link attributes.
    let attributes: [OTLPKeyValue]?

    /// The number of attributes that were dropped due to limits.
    let droppedAttributesCount: UInt32?

    /// W3C trace flags (bitmask, pass through raw SDK value without transformation).
    let flags: UInt32?


    // MARK: - Coding Keys

    private enum CodingKeys: String, CodingKey {
        case traceId
        case spanId
        case traceState
        case attributes
        case droppedAttributesCount
        case flags
    }


    // MARK: - Initialization

    /// Creates a new span link.
    ///
    /// - Parameters:
    ///   - traceId: The trace ID of the linked span.
    ///   - spanId: The span ID of the linked span.
    ///   - traceState: The W3C tracestate header value.
    ///   - attributes: Link attributes.
    ///   - droppedAttributesCount: Number of dropped attributes.
    ///   - flags: W3C trace flags.
    init(
        traceId: OTLPTraceId,
        spanId: OTLPSpanId,
        traceState: String? = nil,
        attributes: [OTLPKeyValue]? = nil,
        droppedAttributesCount: UInt32? = nil,
        flags: UInt32? = nil
    ) {
        self.traceId = traceId
        self.spanId = spanId
        self.traceState = traceState
        self.attributes = attributes
        self.droppedAttributesCount = droppedAttributesCount
        self.flags = flags
    }


    // MARK: - Encodable

    /// Custom encoding to handle optional fields correctly.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: An error if encoding fails.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(traceId, forKey: .traceId)
        try container.encode(spanId, forKey: .spanId)

        if let traceState = traceState, !traceState.isEmpty {
            try container.encode(traceState, forKey: .traceState)
        }

        if let attributes = attributes, !attributes.isEmpty {
            try container.encode(attributes, forKey: .attributes)
        }

        if let count = droppedAttributesCount, count > 0 {
            try container.encode(count, forKey: .droppedAttributesCount)
        }

        if let flags = flags, flags > 0 {
            try container.encode(flags, forKey: .flags)
        }
    }
}
