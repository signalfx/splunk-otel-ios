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

// MARK: - OTLPExponentialHistogram

/// OTLP ExponentialHistogram metric type.
///
/// ExponentialHistogram represents the distribution of values using
/// exponentially growing bucket boundaries. This provides better precision
/// for distributions that span many orders of magnitude.
///
/// Based on OTLP specification v1.9.0.
/// See: https://github.com/open-telemetry/opentelemetry-proto/blob/v1.9.0/opentelemetry/proto/metrics/v1/metrics.proto
struct OTLPExponentialHistogram: Encodable {

    // MARK: - Properties

    /// The data points for this exponential histogram metric.
    let dataPoints: [OTLPExponentialHistogramDataPoint]

    /// The aggregation temporality.
    /// 1 = DELTA (change since last report)
    /// 2 = CUMULATIVE (total since start)
    let aggregationTemporality: Int
}
