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

// MARK: - OTLPHistogramDataPoint

/// OTLP Histogram data point.
///
/// A HistogramDataPoint contains the bucket counts and boundaries for a
/// histogram metric at a specific point in time.
///
/// Based on OTLP specification v1.9.0.
/// See: https://github.com/open-telemetry/opentelemetry-proto/blob/v1.9.0/opentelemetry/proto/metrics/v1/metrics.proto
struct OTLPHistogramDataPoint: Encodable {

    // MARK: - Properties

    /// Key-value pairs of data point attributes.
    let attributes: [OTLPKeyValue]?

    /// Start timestamp (nanoseconds since Unix epoch as decimal string).
    let startTimeUnixNano: OTLPUInt64

    /// Timestamp when this value was recorded (nanoseconds since Unix epoch as decimal string).
    let timeUnixNano: OTLPUInt64

    /// The total count of values in the histogram.
    let count: OTLPUInt64

    /// The sum of all values in the histogram (optional).
    let sum: Double?

    /// The count of values in each bucket.
    ///
    /// Length should be explicitBounds.length + 1.
    let bucketCounts: [OTLPUInt64]

    /// The explicit bucket boundaries.
    /// Creates buckets: (-inf, bounds[0]], (bounds[0], bounds[1]], ..., (bounds[n-1], +inf)
    let explicitBounds: [Double]

    /// Exemplars associated with this data point.
    let exemplars: [OTLPExemplar]?

    /// Flags bitmask (pass through raw SDK value without transformation).
    let flags: UInt32?

    /// The minimum value in the histogram (optional).
    let min: Double?

    /// The maximum value in the histogram (optional).
    let max: Double?


    // MARK: - Coding Keys

    private enum CodingKeys: String, CodingKey {
        case attributes
        case startTimeUnixNano
        case timeUnixNano
        case count
        case sum
        case bucketCounts
        case explicitBounds
        case exemplars
        case flags
        case min
        case max
    }


    // MARK: - Initialization

    /// Creates a new histogram data point.
    ///
    /// - Parameters:
    ///   - attributes: Data point attributes.
    ///   - startTimeUnixNano: Start timestamp.
    ///   - timeUnixNano: Recording timestamp.
    ///   - count: Total count of values.
    ///   - sum: Sum of all values.
    ///   - bucketCounts: Count in each bucket.
    ///   - explicitBounds: Bucket boundaries.
    ///   - exemplars: Associated exemplars.
    ///   - flags: Flags bitmask.
    ///   - min: Minimum value.
    ///   - max: Maximum value.
    init(
        attributes: [OTLPKeyValue]? = nil,
        startTimeUnixNano: OTLPUInt64,
        timeUnixNano: OTLPUInt64,
        count: OTLPUInt64,
        sum: Double? = nil,
        bucketCounts: [OTLPUInt64],
        explicitBounds: [Double],
        exemplars: [OTLPExemplar]? = nil,
        flags: UInt32? = nil,
        min: Double? = nil,
        max: Double? = nil
    ) {
        self.attributes = attributes
        self.startTimeUnixNano = startTimeUnixNano
        self.timeUnixNano = timeUnixNano
        self.count = count
        self.sum = sum
        self.bucketCounts = bucketCounts
        self.explicitBounds = explicitBounds
        self.exemplars = exemplars
        self.flags = flags
        self.min = min
        self.max = max
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

        try container.encode(bucketCounts, forKey: .bucketCounts)
        try container.encode(explicitBounds, forKey: .explicitBounds)

        if let exemplars, !exemplars.isEmpty {
            try container.encode(exemplars, forKey: .exemplars)
        }

        // Encode flags when present regardless of value (including zero)
        if let flags {
            try container.encode(flags, forKey: .flags)
        }

        if let min {
            try container.encode(min, forKey: .min)
        }

        if let max {
            try container.encode(max, forKey: .max)
        }
    }
}
