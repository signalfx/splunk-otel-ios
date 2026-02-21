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

// MARK: - OTLPSpan

/// OTLP Span model with all required fields.
///
/// A Span represents a single operation within a trace. It contains timing
/// information, attributes, events, and links to other spans.
///
/// Key encoding notes:
/// - `traceId` and `spanId` are lowercase hex strings (not base64)
/// - `kind` is an integer enum value (0=UNSPECIFIED, 1=INTERNAL, 2=SERVER, 3=CLIENT, 4=PRODUCER, 5=CONSUMER)
/// - Timestamps are nanoseconds as decimal strings
/// - `flags` is a bitmask (W3C trace flags), pass through raw SDK value
///
/// Based on OTLP specification v1.9.0.
/// See: https://github.com/open-telemetry/opentelemetry-proto/blob/v1.9.0/opentelemetry/proto/trace/v1/trace.proto
struct OTLPSpan: Encodable {

    // MARK: - Properties

    /// The trace ID as a lowercase hex string (32 characters).
    let traceId: OTLPTraceId

    /// The span ID as a lowercase hex string (16 characters).
    let spanId: OTLPSpanId

    /// The W3C tracestate header value.
    let traceState: String?

    /// The parent span ID as a lowercase hex string (16 characters), or nil for root spans.
    let parentSpanId: OTLPSpanId?

    /// The span name describing the operation.
    let name: String

    /// The span kind as an integer enum value.
    /// 0=UNSPECIFIED, 1=INTERNAL, 2=SERVER, 3=CLIENT, 4=PRODUCER, 5=CONSUMER
    let kind: Int

    /// Start timestamp in nanoseconds since Unix epoch (as decimal string).
    let startTimeUnixNano: OTLPUInt64

    /// End timestamp in nanoseconds since Unix epoch (as decimal string).
    let endTimeUnixNano: OTLPUInt64

    /// Key-value pairs of span attributes.
    let attributes: [OTLPKeyValue]?

    /// The number of attributes that were dropped due to limits.
    let droppedAttributesCount: UInt32?

    /// Events associated with this span (timestamped annotations).
    let events: [OTLPSpanEvent]?

    /// The number of events that were dropped due to limits.
    let droppedEventsCount: UInt32?

    /// Links to other spans (in the same or different traces).
    let links: [OTLPSpanLink]?

    /// The number of links that were dropped due to limits.
    let droppedLinksCount: UInt32?

    /// The status of this span.
    let status: OTLPStatus?

    /// W3C trace flags (bitmask, pass through raw SDK value without transformation).
    let flags: UInt32?


    // MARK: - Coding Keys

    private enum CodingKeys: String, CodingKey {
        case traceId
        case spanId
        case traceState
        case parentSpanId
        case name
        case kind
        case startTimeUnixNano
        case endTimeUnixNano
        case attributes
        case droppedAttributesCount
        case events
        case droppedEventsCount
        case links
        case droppedLinksCount
        case status
        case flags
    }


    // MARK: - Initialization

    /// Creates a new span.
    ///
    /// - Parameters:
    ///   - traceId: The trace ID.
    ///   - spanId: The span ID.
    ///   - traceState: The W3C tracestate header value.
    ///   - parentSpanId: The parent span ID (nil for root spans).
    ///   - name: The span name.
    ///   - kind: The span kind as an integer.
    ///   - startTimeUnixNano: Start timestamp in nanoseconds.
    ///   - endTimeUnixNano: End timestamp in nanoseconds.
    ///   - attributes: Span attributes.
    ///   - droppedAttributesCount: Number of dropped attributes.
    ///   - events: Span events.
    ///   - droppedEventsCount: Number of dropped events.
    ///   - links: Span links.
    ///   - droppedLinksCount: Number of dropped links.
    ///   - status: Span status.
    ///   - flags: W3C trace flags.
    init(
        traceId: OTLPTraceId,
        spanId: OTLPSpanId,
        traceState: String? = nil,
        parentSpanId: OTLPSpanId? = nil,
        name: String,
        kind: Int,
        startTimeUnixNano: OTLPUInt64,
        endTimeUnixNano: OTLPUInt64,
        attributes: [OTLPKeyValue]? = nil,
        droppedAttributesCount: UInt32? = nil,
        events: [OTLPSpanEvent]? = nil,
        droppedEventsCount: UInt32? = nil,
        links: [OTLPSpanLink]? = nil,
        droppedLinksCount: UInt32? = nil,
        status: OTLPStatus? = nil,
        flags: UInt32? = nil
    ) {
        self.traceId = traceId
        self.spanId = spanId
        self.traceState = traceState
        self.parentSpanId = parentSpanId
        self.name = name
        self.kind = kind
        self.startTimeUnixNano = startTimeUnixNano
        self.endTimeUnixNano = endTimeUnixNano
        self.attributes = attributes
        self.droppedAttributesCount = droppedAttributesCount
        self.events = events
        self.droppedEventsCount = droppedEventsCount
        self.links = links
        self.droppedLinksCount = droppedLinksCount
        self.status = status
        self.flags = flags
    }


    // MARK: - Encodable

    /// Custom encoding to handle optional fields and drop counts correctly.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: An error if encoding fails.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // Required fields
        try container.encode(traceId, forKey: .traceId)
        try container.encode(spanId, forKey: .spanId)
        try container.encode(name, forKey: .name)
        try container.encode(kind, forKey: .kind)
        try container.encode(startTimeUnixNano, forKey: .startTimeUnixNano)
        try container.encode(endTimeUnixNano, forKey: .endTimeUnixNano)

        // Optional fields
        if let traceState, !traceState.isEmpty {
            try container.encode(traceState, forKey: .traceState)
        }

        if let parentSpanId {
            try container.encode(parentSpanId, forKey: .parentSpanId)
        }

        if let attributes, !attributes.isEmpty {
            try container.encode(attributes, forKey: .attributes)
        }

        if let count = droppedAttributesCount, count > 0 {
            try container.encode(count, forKey: .droppedAttributesCount)
        }

        if let events, !events.isEmpty {
            try container.encode(events, forKey: .events)
        }

        if let count = droppedEventsCount, count > 0 {
            try container.encode(count, forKey: .droppedEventsCount)
        }

        if let links, !links.isEmpty {
            try container.encode(links, forKey: .links)
        }

        if let count = droppedLinksCount, count > 0 {
            try container.encode(count, forKey: .droppedLinksCount)
        }

        if let status {
            try container.encode(status, forKey: .status)
        }

        // Encode flags when present regardless of value (including zero)
        // Zero flags means "not sampled" in W3C trace context - valid semantic value
        if let flags {
            try container.encode(flags, forKey: .flags)
        }
    }
}
