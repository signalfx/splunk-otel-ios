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

// MARK: - OTLPSum

/// OTLP Sum metric type (counters).
///
/// Sum represents a cumulative or delta aggregation over time. This is
/// typically used for counters that track things like request count,
/// bytes transferred, or errors.
///
/// Based on OTLP specification v1.9.0.
/// See: https://github.com/open-telemetry/opentelemetry-proto/blob/v1.9.0/opentelemetry/proto/metrics/v1/metrics.proto
struct OTLPSum: Encodable {

    // MARK: - Aggregation Temporality Constants

    /// Delta temporality - each data point represents the change since the last report.
    static let aggregationTemporalityDelta = 1

    /// Cumulative temporality - each data point represents the total since a start time.
    static let aggregationTemporalityCumulative = 2


    // MARK: - Properties

    /// The data points for this sum metric.
    let dataPoints: [OTLPNumberDataPoint]

    /// The aggregation temporality.
    /// 1 = DELTA (change since last report)
    /// 2 = CUMULATIVE (total since start)
    let aggregationTemporality: Int

    /// Whether the sum is monotonic (always increasing, like a counter).
    let isMonotonic: Bool
}
