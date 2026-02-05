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

// MARK: - OTLPExemplar

/// OTLP Exemplar model.
///
/// An Exemplar is a sample value with associated trace context. Exemplars
/// are used to link metric data points to specific trace spans that
/// contributed to the metric value.
///
/// The value uses a "oneof" pattern - either asDouble or asInt, never both.
///
/// Based on OTLP specification v1.9.0.
/// See: https://github.com/open-telemetry/opentelemetry-proto/blob/v1.9.0/opentelemetry/proto/metrics/v1/metrics.proto
struct OTLPExemplar: Encodable {

    // MARK: - Properties

    /// Attributes that were filtered out during aggregation but recorded for this exemplar.
    let filteredAttributes: [OTLPKeyValue]?

    /// The timestamp of this exemplar (nanoseconds since Unix epoch as decimal string).
    let timeUnixNano: OTLPUInt64

    /// The value as a double (oneof - use this OR asInt).
    let asDouble: Double?

    /// The value as an integer (oneof - use this OR asDouble).
    let asInt: OTLPInt64?

    /// The span ID of the trace span this exemplar is associated with.
    let spanId: OTLPSpanId?

    /// The trace ID of the trace this exemplar is associated with.
    let traceId: OTLPTraceId?

    /// Flags bitmask (reserved for future use, pass through raw SDK value).
    let flags: UInt32?


    // MARK: - Coding Keys

    private enum CodingKeys: String, CodingKey {
        case filteredAttributes
        case timeUnixNano
        case asDouble
        case asInt
        case spanId
        case traceId
        case flags
    }


    // MARK: - Initialization

    /// Creates a new exemplar.
    ///
    /// - Parameters:
    ///   - filteredAttributes: Attributes that were filtered out.
    ///   - timeUnixNano: The timestamp of this exemplar.
    ///   - asDouble: The value as a double (mutually exclusive with asInt).
    ///   - asInt: The value as an integer (mutually exclusive with asDouble).
    ///   - spanId: The span ID for trace context.
    ///   - traceId: The trace ID for trace context.
    ///   - flags: Flags bitmask.
    init(
        filteredAttributes: [OTLPKeyValue]? = nil,
        timeUnixNano: OTLPUInt64,
        asDouble: Double? = nil,
        asInt: OTLPInt64? = nil,
        spanId: OTLPSpanId? = nil,
        traceId: OTLPTraceId? = nil,
        flags: UInt32? = nil
    ) {
        self.filteredAttributes = filteredAttributes
        self.timeUnixNano = timeUnixNano
        self.asDouble = asDouble
        self.asInt = asInt
        self.spanId = spanId
        self.traceId = traceId
        self.flags = flags
    }


    // MARK: - Encodable

    /// Custom encoding to handle optional fields correctly.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: An error if encoding fails.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        if let filteredAttributes, !filteredAttributes.isEmpty {
            try container.encode(filteredAttributes, forKey: .filteredAttributes)
        }

        try container.encode(timeUnixNano, forKey: .timeUnixNano)

        // Oneof value - encode only one
        if let asDouble {
            try container.encode(asDouble, forKey: .asDouble)
        }
        else if let asInt {
            try container.encode(asInt, forKey: .asInt)
        }

        if let spanId {
            try container.encode(spanId, forKey: .spanId)
        }

        if let traceId {
            try container.encode(traceId, forKey: .traceId)
        }

        // Encode flags when present regardless of value (including zero)
        if let flags {
            try container.encode(flags, forKey: .flags)
        }
    }
}
