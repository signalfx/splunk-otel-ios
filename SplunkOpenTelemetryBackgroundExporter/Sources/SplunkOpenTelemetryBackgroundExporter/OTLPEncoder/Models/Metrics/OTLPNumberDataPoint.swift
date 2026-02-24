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

// MARK: - OTLPNumberDataPoint

/// OTLP NumberDataPoint for Gauge and Sum metrics.
///
/// A NumberDataPoint represents a single data point with a numeric value.
/// The value uses a "oneof" pattern - either asDouble or asInt, never both.
///
/// Based on OTLP specification v1.9.0.
/// See: https://github.com/open-telemetry/opentelemetry-proto/blob/v1.9.0/opentelemetry/proto/metrics/v1/metrics.proto
struct OTLPNumberDataPoint: Encodable {

    // MARK: - Properties

    /// Key-value pairs of data point attributes.
    let attributes: [OTLPKeyValue]?

    /// Start timestamp (nanoseconds since Unix epoch as decimal string).
    ///
    /// Optional for Gauge metrics.
    let startTimeUnixNano: OTLPUInt64?

    /// Timestamp when this value was recorded (nanoseconds since Unix epoch as decimal string).
    let timeUnixNano: OTLPUInt64

    /// The value as a double (oneof - use this OR asInt).
    let asDouble: Double?

    /// The value as an integer (oneof - use this OR asDouble).
    let asInt: OTLPInt64?

    /// Exemplars associated with this data point.
    let exemplars: [OTLPExemplar]?

    /// Flags bitmask (pass through raw SDK value without transformation).
    let flags: UInt32?


    // MARK: - Coding Keys

    private enum CodingKeys: String, CodingKey {
        case attributes
        case startTimeUnixNano
        case timeUnixNano
        case asDouble
        case asInt
        case exemplars
        case flags
    }


    // MARK: - Initialization

    /// Creates a new number data point.
    ///
    /// - Parameters:
    ///   - attributes: Data point attributes.
    ///   - startTimeUnixNano: Start timestamp (optional for Gauge).
    ///   - timeUnixNano: Recording timestamp.
    ///   - asDouble: Value as double (mutually exclusive with asInt).
    ///   - asInt: Value as integer (mutually exclusive with asDouble).
    ///   - exemplars: Associated exemplars.
    ///   - flags: Flags bitmask.
    init(
        attributes: [OTLPKeyValue]? = nil,
        startTimeUnixNano: OTLPUInt64? = nil,
        timeUnixNano: OTLPUInt64,
        asDouble: Double? = nil,
        asInt: OTLPInt64? = nil,
        exemplars: [OTLPExemplar]? = nil,
        flags: UInt32? = nil
    ) {
        self.attributes = attributes
        self.startTimeUnixNano = startTimeUnixNano
        self.timeUnixNano = timeUnixNano
        self.asDouble = asDouble
        self.asInt = asInt
        self.exemplars = exemplars
        self.flags = flags
    }


    // MARK: - Encodable

    /// Custom encoding to handle optional fields and oneof value correctly.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: An error if encoding fails.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        if let attributes, !attributes.isEmpty {
            try container.encode(attributes, forKey: .attributes)
        }

        if let startTimeUnixNano {
            try container.encode(startTimeUnixNano, forKey: .startTimeUnixNano)
        }

        try container.encode(timeUnixNano, forKey: .timeUnixNano)

        // Oneof value - encode only one
        if let asDouble {
            try container.encode(asDouble, forKey: .asDouble)
        }
        else if let asInt {
            try container.encode(asInt, forKey: .asInt)
        }

        if let exemplars, !exemplars.isEmpty {
            try container.encode(exemplars, forKey: .exemplars)
        }

        // Encode flags when present regardless of value (including zero)
        if let flags {
            try container.encode(flags, forKey: .flags)
        }
    }
}
