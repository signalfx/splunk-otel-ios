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

// MARK: - OTLPLogRecord

/// OTLP LogRecord model.
///
/// A LogRecord represents a single log entry. It contains timing information,
/// severity, body content, and attributes.
///
/// NOTE: There is NO eventName field in OTLP LogRecord proto.
/// Event semantics are conveyed via attributes per OpenTelemetry semantic conventions.
///
/// Key encoding notes:
/// - `traceId` and `spanId` are lowercase hex strings (not base64)
/// - `severityNumber` is an integer enum (1-24)
/// - Timestamps are nanoseconds as decimal strings
/// - `body` can contain binary data via `bytesValue` with base64 encoding
///
/// Based on OTLP specification v1.9.0.
/// See: https://github.com/open-telemetry/opentelemetry-proto/blob/v1.9.0/opentelemetry/proto/logs/v1/logs.proto
struct OTLPLogRecord: Encodable {

    // MARK: - Properties

    /// Time when the event occurred (nanoseconds since Unix epoch as decimal string).
    ///
    /// May be nil if the timestamp is unknown.
    let timeUnixNano: OTLPUInt64?

    /// Time when the event was observed (nanoseconds since Unix epoch as decimal string).
    ///
    /// This is typically when the log was collected by the SDK.
    let observedTimeUnixNano: OTLPUInt64

    /// Severity number as an integer enum (1-24).
    ///
    /// Maps to TRACE=1-4, DEBUG=5-8, INFO=9-12, WARN=13-16, ERROR=17-20, FATAL=21-24.
    let severityNumber: Int?

    /// Human-readable severity text (e.g., "INFO", "ERROR").
    let severityText: String?

    /// The log message body.
    ///
    /// Can be any type including bytesValue for binary data.
    let body: OTLPAnyValue?

    /// Key-value pairs of log record attributes.
    let attributes: [OTLPKeyValue]?

    /// The number of attributes that were dropped due to limits.
    let droppedAttributesCount: UInt32?

    /// Flags as a bitmask (reserved for future use).
    let flags: UInt32?

    /// The trace ID for correlation with tracing (lowercase hex string, 32 characters).
    let traceId: OTLPTraceId?

    /// The span ID for correlation with tracing (lowercase hex string, 16 characters).
    let spanId: OTLPSpanId?

    // NOTE: There is NO eventName field - not part of OTLP proto


    // MARK: - Coding Keys

    private enum CodingKeys: String, CodingKey {
        case timeUnixNano
        case observedTimeUnixNano
        case severityNumber
        case severityText
        case body
        case attributes
        case droppedAttributesCount
        case flags
        case traceId
        case spanId
    }


    // MARK: - Initialization

    /// Creates a new log record.
    ///
    /// - Parameters:
    ///   - timeUnixNano: Time when the event occurred.
    ///   - observedTimeUnixNano: Time when the event was observed.
    ///   - severityNumber: Severity number (1-24).
    ///   - severityText: Human-readable severity text.
    ///   - body: The log message body.
    ///   - attributes: Log record attributes.
    ///   - droppedAttributesCount: Number of dropped attributes.
    ///   - flags: Flags bitmask.
    ///   - traceId: Trace ID for correlation.
    ///   - spanId: Span ID for correlation.
    init(
        timeUnixNano: OTLPUInt64? = nil,
        observedTimeUnixNano: OTLPUInt64,
        severityNumber: Int? = nil,
        severityText: String? = nil,
        body: OTLPAnyValue? = nil,
        attributes: [OTLPKeyValue]? = nil,
        droppedAttributesCount: UInt32? = nil,
        flags: UInt32? = nil,
        traceId: OTLPTraceId? = nil,
        spanId: OTLPSpanId? = nil
    ) {
        self.timeUnixNano = timeUnixNano
        self.observedTimeUnixNano = observedTimeUnixNano
        self.severityNumber = severityNumber
        self.severityText = severityText
        self.body = body
        self.attributes = attributes
        self.droppedAttributesCount = droppedAttributesCount
        self.flags = flags
        self.traceId = traceId
        self.spanId = spanId
    }


    // MARK: - Encodable

    /// Custom encoding to handle optional fields correctly.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: An error if encoding fails.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // Required field
        try container.encode(observedTimeUnixNano, forKey: .observedTimeUnixNano)

        // Optional fields
        if let timeUnixNano {
            try container.encode(timeUnixNano, forKey: .timeUnixNano)
        }

        if let severityNumber {
            try container.encode(severityNumber, forKey: .severityNumber)
        }

        if let severityText, !severityText.isEmpty {
            try container.encode(severityText, forKey: .severityText)
        }

        if let body {
            try container.encode(body, forKey: .body)
        }

        if let attributes, !attributes.isEmpty {
            try container.encode(attributes, forKey: .attributes)
        }

        if let count = droppedAttributesCount, count > 0 {
            try container.encode(count, forKey: .droppedAttributesCount)
        }

        // Encode flags when present regardless of value (including zero)
        // Zero flags means "not sampled" in W3C trace context - valid semantic value
        if let flags {
            try container.encode(flags, forKey: .flags)
        }

        if let traceId {
            try container.encode(traceId, forKey: .traceId)
        }

        if let spanId {
            try container.encode(spanId, forKey: .spanId)
        }
    }
}
