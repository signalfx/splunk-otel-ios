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
import OpenTelemetryApi
import OpenTelemetrySdk

// MARK: - MetricDataAdapter

/// Adapter for converting OpenTelemetry SDK MetricData to OTLP JSON models.
///
/// This adapter handles:
/// - Grouping metrics by resource and instrumentation scope
/// - Converting various metric types (gauge, sum, histogram, summary)
/// - Filtering out empty envelopes per OTLP spec
///
/// NOTE: This implementation provides metric conversion for common metric types.
/// The actual metric point conversion depends on the specific OpenTelemetrySdk types
/// being used and may need adjustment based on SDK version.
///
/// Based on OTLP specification v1.9.0.
enum MetricDataAdapter {

    // MARK: - Internal Methods

    /// Converts a list of MetricData to OTLP ResourceMetrics.
    ///
    /// Groups metrics by resource and instrumentation scope, then converts them to
    /// OTLP JSON models. Empty envelopes are filtered out.
    ///
    /// - Parameter metrics: The list of MetricData to convert.
    /// - Returns: A list of OTLPResourceMetrics (non-empty).
    static func toResourceMetrics(_ metrics: [MetricData]) -> [OTLPResourceMetrics] {
        // Group metrics by resource first
        let groupedByResource = groupByResource(metrics)

        var resourceMetricsList: [OTLPResourceMetrics] = []

        for (resource, metricDataList) in groupedByResource {
            // Group metrics within this resource by scope
            let groupedByScope = groupByScope(metricDataList)

            var scopeMetricsList: [OTLPScopeMetrics] = []

            for (scopeInfo, scopedMetrics) in groupedByScope {
                // Convert each MetricData to OTLPMetric
                let otlpMetrics = scopedMetrics.compactMap { convertMetric($0) }

                // Skip empty scope metrics (filter empty envelopes per OTLP spec)
                guard !otlpMetrics.isEmpty else {
                    continue
                }

                let scopeMetrics = OTLPScopeMetrics(
                    scope: convertInstrumentationScope(scopeInfo),
                    metrics: otlpMetrics,
                    schemaUrl: scopeInfo.schemaUrl
                )
                scopeMetricsList.append(scopeMetrics)
            }

            // Skip empty resource metrics (filter empty envelopes per OTLP spec)
            guard !scopeMetricsList.isEmpty else {
                continue
            }

            let resourceMetrics = OTLPResourceMetrics(
                resource: convertResource(resource),
                scopeMetrics: scopeMetricsList,
                schemaUrl: nil // Resource.schemaUrl not available in current SDK version
            )
            resourceMetricsList.append(resourceMetrics)
        }

        return resourceMetricsList
    }
}
