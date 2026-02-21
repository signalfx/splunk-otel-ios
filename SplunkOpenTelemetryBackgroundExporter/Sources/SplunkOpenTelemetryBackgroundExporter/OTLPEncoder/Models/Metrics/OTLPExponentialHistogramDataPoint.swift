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

// MARK: - OTLPExponentialHistogramDataPoint

/// OTLP Exponential Histogram data point.
///
/// An ExponentialHistogramDataPoint contains the bucket counts using
/// exponential bucket boundaries for a histogram metric at a specific
/// point in time.
///
/// Based on OTLP specification v1.9.0.
/// See: https://github.com/open-telemetry/opentelemetry-proto/blob/v1.9.0/opentelemetry/proto/metrics/v1/metrics.proto
struct OTLPExponentialHistogramDataPoint: Encodable {

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

    /// The scale factor determining bucket boundaries.
    let scale: Int32

    /// The count of values at zero.
    let zeroCount: OTLPUInt64

    /// Buckets for positive values.
    let positive: OTLPBuckets

    /// Buckets for negative values.
    let negative: OTLPBuckets

    /// Flags bitmask (pass through raw SDK value without transformation).
    let flags: UInt32?

    /// Exemplars associated with this data point.
    let exemplars: [OTLPExemplar]?

    /// The minimum value in the histogram (optional).
    let min: Double?

    /// The maximum value in the histogram (optional).
    let max: Double?

    /// The threshold below which values are considered zero.
    let zeroThreshold: Double?


    // MARK: - Coding Keys

    private enum CodingKeys: String, CodingKey {
        case attributes
        case startTimeUnixNano
        case timeUnixNano
        case count
        case sum
        case scale
        case zeroCount
        case positive
        case negative
        case flags
        case exemplars
        case min
        case max
        case zeroThreshold
    }


    // MARK: - Initialization

    /// Creates a new exponential histogram data point.
    ///
    /// - Parameters:
    ///   - attributes: Data point attributes.
    ///   - startTimeUnixNano: Start timestamp.
    ///   - timeUnixNano: Recording timestamp.
    ///   - count: Total count of values.
    ///   - sum: Sum of all values.
    ///   - scale: Scale factor for bucket boundaries.
    ///   - zeroCount: Count of values at zero.
    ///   - positive: Positive value buckets.
    ///   - negative: Negative value buckets.
    ///   - flags: Flags bitmask.
    ///   - exemplars: Associated exemplars.
    ///   - min: Minimum value.
    ///   - max: Maximum value.
    ///   - zeroThreshold: Zero threshold.
    init(
        attributes: [OTLPKeyValue]? = nil,
        startTimeUnixNano: OTLPUInt64,
        timeUnixNano: OTLPUInt64,
        count: OTLPUInt64,
        sum: Double? = nil,
        scale: Int32,
        zeroCount: OTLPUInt64,
        positive: OTLPBuckets,
        negative: OTLPBuckets,
        flags: UInt32? = nil,
        exemplars: [OTLPExemplar]? = nil,
        min: Double? = nil,
        max: Double? = nil,
        zeroThreshold: Double? = nil
    ) {
        self.attributes = attributes
        self.startTimeUnixNano = startTimeUnixNano
        self.timeUnixNano = timeUnixNano
        self.count = count
        self.sum = sum
        self.scale = scale
        self.zeroCount = zeroCount
        self.positive = positive
        self.negative = negative
        self.flags = flags
        self.exemplars = exemplars
        self.min = min
        self.max = max
        self.zeroThreshold = zeroThreshold
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

        try container.encode(scale, forKey: .scale)
        try container.encode(zeroCount, forKey: .zeroCount)
        try container.encode(positive, forKey: .positive)
        try container.encode(negative, forKey: .negative)

        // Encode flags when present regardless of value (including zero)
        if let flags {
            try container.encode(flags, forKey: .flags)
        }

        if let exemplars, !exemplars.isEmpty {
            try container.encode(exemplars, forKey: .exemplars)
        }

        if let min {
            try container.encode(min, forKey: .min)
        }

        if let max {
            try container.encode(max, forKey: .max)
        }

        if let zeroThreshold {
            try container.encode(zeroThreshold, forKey: .zeroThreshold)
        }
    }
}
