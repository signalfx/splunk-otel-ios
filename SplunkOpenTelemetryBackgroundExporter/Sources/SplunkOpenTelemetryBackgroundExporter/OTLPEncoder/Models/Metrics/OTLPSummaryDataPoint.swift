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

// MARK: - OTLPSummaryDataPoint

/// OTLP Summary data point.
///
/// A SummaryDataPoint contains quantile values for a summary metric at a
/// specific point in time.
///
/// Based on OTLP specification v1.9.0.
/// See: https://github.com/open-telemetry/opentelemetry-proto/blob/v1.9.0/opentelemetry/proto/metrics/v1/metrics.proto
struct OTLPSummaryDataPoint: Encodable {

    // MARK: - Properties

    /// Key-value pairs of data point attributes.
    let attributes: [OTLPKeyValue]?

    /// Start timestamp (nanoseconds since Unix epoch as decimal string).
    let startTimeUnixNano: OTLPUInt64

    /// Timestamp when this value was recorded (nanoseconds since Unix epoch as decimal string).
    let timeUnixNano: OTLPUInt64

    /// The total count of observations.
    let count: OTLPUInt64

    /// The sum of all observations (optional per proto).
    let sum: Double?

    /// The quantile values.
    let quantileValues: [OTLPQuantileValue]

    /// Flags bitmask (pass through raw SDK value without transformation).
    let flags: UInt32?


    // MARK: - Coding Keys

    private enum CodingKeys: String, CodingKey {
        case attributes
        case startTimeUnixNano
        case timeUnixNano
        case count
        case sum
        case quantileValues
        case flags
    }


    // MARK: - Initialization

    /// Creates a new summary data point.
    ///
    /// - Parameters:
    ///   - attributes: Data point attributes.
    ///   - startTimeUnixNano: Start timestamp.
    ///   - timeUnixNano: Recording timestamp.
    ///   - count: Total count of observations.
    ///   - sum: Sum of all observations (optional).
    ///   - quantileValues: The quantile values.
    ///   - flags: Flags bitmask.
    init(
        attributes: [OTLPKeyValue]? = nil,
        startTimeUnixNano: OTLPUInt64,
        timeUnixNano: OTLPUInt64,
        count: OTLPUInt64,
        sum: Double? = nil,
        quantileValues: [OTLPQuantileValue],
        flags: UInt32? = nil
    ) {
        self.attributes = attributes
        self.startTimeUnixNano = startTimeUnixNano
        self.timeUnixNano = timeUnixNano
        self.count = count
        self.sum = sum
        self.quantileValues = quantileValues
        self.flags = flags
    }


    // MARK: - Encodable

    /// Custom encoding to handle optional fields correctly.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: An error if encoding fails.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        if let attributes, !attributes.isEmpty {
            try container.encode(attributes, forKey: .attributes)
        }

        try container.encode(startTimeUnixNano, forKey: .startTimeUnixNano)
        try container.encode(timeUnixNano, forKey: .timeUnixNano)
        try container.encode(count, forKey: .count)

        if let sum {
            try container.encode(sum, forKey: .sum)
        }

        try container.encode(quantileValues, forKey: .quantileValues)

        // Encode flags when present regardless of value (including zero)
        if let flags {
            try container.encode(flags, forKey: .flags)
        }
    }
}
