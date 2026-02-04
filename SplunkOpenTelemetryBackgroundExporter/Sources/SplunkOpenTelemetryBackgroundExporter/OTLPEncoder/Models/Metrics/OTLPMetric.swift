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


// MARK: - OTLPMetric

/// OTLP Metric model.
///
/// A Metric represents a single metric with its data. The data field uses a
/// "oneof" pattern - only one of gauge, sum, histogram, exponentialHistogram,
/// or summary should be set.
///
/// Based on OTLP specification v1.9.0.
/// See: https://github.com/open-telemetry/opentelemetry-proto/blob/v1.9.0/opentelemetry/proto/metrics/v1/metrics.proto
struct OTLPMetric: Encodable {

    // MARK: - Properties

    /// The metric name.
    let name: String

    /// A description of the metric.
    let description: String?

    /// The unit of measurement (e.g., "ms", "bytes", "1").
    let unit: String?

    /// Gauge data (oneof - only one data type should be set).
    let gauge: OTLPGauge?

    /// Sum data (oneof - only one data type should be set).
    let sum: OTLPSum?

    /// Histogram data (oneof - only one data type should be set).
    let histogram: OTLPHistogram?

    /// Exponential histogram data (oneof - only one data type should be set).
    let exponentialHistogram: OTLPExponentialHistogram?

    /// Summary data (oneof - only one data type should be set).
    let summary: OTLPSummary?


    // MARK: - Coding Keys

    private enum CodingKeys: String, CodingKey {
        case name
        case description
        case unit
        case gauge
        case sum
        case histogram
        case exponentialHistogram
        case summary
    }


    // MARK: - Initialization

    /// Creates a new metric.
    ///
    /// - Parameters:
    ///   - name: The metric name.
    ///   - description: A description of the metric.
    ///   - unit: The unit of measurement.
    ///   - gauge: Gauge data (mutually exclusive with other data types).
    ///   - sum: Sum data (mutually exclusive with other data types).
    ///   - histogram: Histogram data (mutually exclusive with other data types).
    ///   - exponentialHistogram: Exponential histogram data (mutually exclusive with other data types).
    ///   - summary: Summary data (mutually exclusive with other data types).
    init(
        name: String,
        description: String? = nil,
        unit: String? = nil,
        gauge: OTLPGauge? = nil,
        sum: OTLPSum? = nil,
        histogram: OTLPHistogram? = nil,
        exponentialHistogram: OTLPExponentialHistogram? = nil,
        summary: OTLPSummary? = nil
    ) {
        self.name = name
        self.description = description
        self.unit = unit
        self.gauge = gauge
        self.sum = sum
        self.histogram = histogram
        self.exponentialHistogram = exponentialHistogram
        self.summary = summary
    }


    // MARK: - Encodable

    /// Custom encoding to handle optional fields correctly.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: An error if encoding fails.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(name, forKey: .name)

        if let description = description, !description.isEmpty {
            try container.encode(description, forKey: .description)
        }

        if let unit = unit, !unit.isEmpty {
            try container.encode(unit, forKey: .unit)
        }

        // Oneof data - only encode the one that is set
        if let gauge = gauge {
            try container.encode(gauge, forKey: .gauge)
        } else if let sum = sum {
            try container.encode(sum, forKey: .sum)
        } else if let histogram = histogram {
            try container.encode(histogram, forKey: .histogram)
        } else if let exponentialHistogram = exponentialHistogram {
            try container.encode(exponentialHistogram, forKey: .exponentialHistogram)
        } else if let summary = summary {
            try container.encode(summary, forKey: .summary)
        }
    }
}
