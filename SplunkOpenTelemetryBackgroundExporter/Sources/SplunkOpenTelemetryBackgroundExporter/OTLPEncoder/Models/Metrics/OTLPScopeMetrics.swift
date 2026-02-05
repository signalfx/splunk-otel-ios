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

// MARK: - OTLPScopeMetrics

/// Container for metrics from a single instrumentation scope.
///
/// ScopeMetrics groups all metrics that were produced by the same
/// instrumentation library/scope. This allows receivers to process metrics
/// from the same instrumentation together.
///
/// Based on OTLP specification v1.9.0.
/// See: https://github.com/open-telemetry/opentelemetry-proto/blob/v1.9.0/opentelemetry/proto/metrics/v1/metrics.proto
struct OTLPScopeMetrics: Encodable {

    // MARK: - Properties

    /// The instrumentation scope that produced these metrics.
    let scope: OTLPInstrumentationScope?

    /// The list of metrics from this scope.
    let metrics: [OTLPMetric]

    /// The schema URL for the instrumentation scope.
    let schemaUrl: String?


    // MARK: - Coding Keys

    private enum CodingKeys: String, CodingKey {
        case scope
        case metrics
        case schemaUrl
    }


    // MARK: - Initialization

    /// Creates a new ScopeMetrics container.
    ///
    /// - Parameters:
    ///   - scope: The instrumentation scope that produced these metrics.
    ///   - metrics: The list of metrics from this scope.
    ///   - schemaUrl: The schema URL for the instrumentation scope.
    init(
        scope: OTLPInstrumentationScope?,
        metrics: [OTLPMetric],
        schemaUrl: String? = nil
    ) {
        self.scope = scope
        self.metrics = metrics
        self.schemaUrl = schemaUrl
    }


    // MARK: - Encodable

    /// Custom encoding to handle optional fields correctly.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: An error if encoding fails.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        if let scope {
            try container.encode(scope, forKey: .scope)
        }

        try container.encode(metrics, forKey: .metrics)

        if let schemaUrl, !schemaUrl.isEmpty {
            try container.encode(schemaUrl, forKey: .schemaUrl)
        }
    }
}
