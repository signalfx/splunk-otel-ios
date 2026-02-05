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

// MARK: - OTLPHistogram

/// OTLP Histogram metric type.
///
/// Histogram represents the distribution of values across explicit bucket
/// boundaries. This is useful for measuring things like request latencies
/// or response sizes.
///
/// Based on OTLP specification v1.9.0.
/// See: https://github.com/open-telemetry/opentelemetry-proto/blob/v1.9.0/opentelemetry/proto/metrics/v1/metrics.proto
struct OTLPHistogram: Encodable {

    // MARK: - Properties

    /// The data points for this histogram metric.
    let dataPoints: [OTLPHistogramDataPoint]

    /// The aggregation temporality.
    /// 1 = DELTA (change since last report)
    /// 2 = CUMULATIVE (total since start)
    let aggregationTemporality: Int


    // MARK: - Initialization

    /// Creates a new histogram metric.
    ///
    /// - Parameters:
    ///   - dataPoints: The data points for this histogram.
    ///   - aggregationTemporality: 1=DELTA, 2=CUMULATIVE.
    init(dataPoints: [OTLPHistogramDataPoint], aggregationTemporality: Int) {
        self.dataPoints = dataPoints
        self.aggregationTemporality = aggregationTemporality
    }
}
