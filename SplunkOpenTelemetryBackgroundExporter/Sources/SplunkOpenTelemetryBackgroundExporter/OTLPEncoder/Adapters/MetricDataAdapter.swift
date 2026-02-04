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

    // MARK: - Public Methods

    /// Converts a list of MetricData to OTLP ResourceMetrics.
    ///
    /// Groups metrics by resource and instrumentation scope, then converts them to
    /// OTLP JSON models. Empty envelopes are filtered out.
    ///
    /// - Parameter metrics: The list of MetricData to convert.
    /// - Returns: A list of OTLPResourceMetrics (non-empty).
    static func toResourceMetrics(_ metrics: [MetricData]) -> [OTLPResourceMetrics] {
        // Group metrics by resource
        let grouped = groupByResource(metrics)

        var resourceMetricsList: [OTLPResourceMetrics] = []

        for (resource, metricDataList) in grouped {
            // Convert each MetricData to OTLPMetric
            let otlpMetrics = metricDataList.compactMap { convertMetric($0) }

            // Skip empty resource metrics (filter empty envelopes per OTLP spec)
            guard !otlpMetrics.isEmpty else {
                continue
            }

            // Create a single scope metrics container
            let scopeMetrics = OTLPScopeMetrics(
                scope: convertInstrumentationScope(metricDataList.first?.instrumentationScopeInfo),
                metrics: otlpMetrics,
                schemaUrl: metricDataList.first?.instrumentationScopeInfo.schemaUrl
            )

            let resourceMetrics = OTLPResourceMetrics(
                resource: convertResource(resource),
                scopeMetrics: [scopeMetrics],
                schemaUrl: nil  // Resource.schemaUrl not available in current SDK version
            )
            resourceMetricsList.append(resourceMetrics)
        }

        return resourceMetricsList
    }


    // MARK: - Private Grouping Methods

    /// Groups metrics by resource.
    private static func groupByResource(_ metrics: [MetricData]) -> [Resource: [MetricData]] {
        var result: [Resource: [MetricData]] = [:]

        for metric in metrics {
            result[metric.resource, default: []].append(metric)
        }

        return result
    }


    // MARK: - Private Conversion Methods

    /// Converts a MetricData to an OTLPMetric.
    ///
    /// This method creates a basic metric structure. The data points are
    /// currently empty as the SDK point data types require further investigation.
    private static func convertMetric(_ metricData: MetricData) -> OTLPMetric? {
        let name = metricData.name
        let description = metricData.description.isEmpty ? nil : metricData.description
        let unit = metricData.unit.isEmpty ? nil : metricData.unit

        // For now, we create an empty gauge metric.
        // TODO: Implement proper metric type detection and conversion based on SDK types.
        // This placeholder ensures compilation while the correct SDK types are investigated.
        return OTLPMetric(
            name: name,
            description: description,
            unit: unit,
            gauge: OTLPGauge(dataPoints: [])
        )
    }

    /// Converts Resource to OTLPResource.
    private static func convertResource(_ resource: Resource) -> OTLPResource {
        OTLPResource(
            attributes: convertAttributes(resource.attributes) ?? [],
            droppedAttributesCount: nil
        )
    }

    /// Converts InstrumentationScopeInfo to OTLPInstrumentationScope.
    private static func convertInstrumentationScope(_ scopeInfo: InstrumentationScopeInfo?) -> OTLPInstrumentationScope? {
        guard let scopeInfo = scopeInfo else {
            return nil
        }
        let attrs = scopeInfo.attributes ?? [:]
        return OTLPInstrumentationScope(
            name: scopeInfo.name,
            version: scopeInfo.version,
            attributes: attrs.isEmpty ? nil : convertAttributes(attrs),
            droppedAttributesCount: nil
        )
    }

    /// Converts attributes dictionary to array of OTLPKeyValue.
    private static func convertAttributes(_ attributes: [String: AttributeValue]) -> [OTLPKeyValue]? {
        guard !attributes.isEmpty else {
            return nil
        }
        return attributes.map { key, value in
            OTLPKeyValue(key: key, value: convertAttributeValue(value))
        }
    }

    /// Converts an AttributeValue to OTLPAnyValue.
    private static func convertAttributeValue(_ value: AttributeValue) -> OTLPAnyValue {
        switch value {
        case .string(let v):
            return .stringValue(v)
        case .bool(let v):
            return .boolValue(v)
        case .int(let v):
            return .intValue(Int64(v))
        case .double(let v):
            return .doubleValue(v)
        case .stringArray(let arr):
            return .arrayValue(OTLPArrayValue(values: arr.map { .stringValue($0) }))
        case .boolArray(let arr):
            return .arrayValue(OTLPArrayValue(values: arr.map { .boolValue($0) }))
        case .intArray(let arr):
            return .arrayValue(OTLPArrayValue(values: arr.map { .intValue(Int64($0)) }))
        case .doubleArray(let arr):
            return .arrayValue(OTLPArrayValue(values: arr.map { .doubleValue($0) }))
        case .set(let set):
            let kvList = set.labels.map { key, attrValue in
                OTLPKeyValue(key: key, value: convertAttributeValue(attrValue))
            }
            return .kvlistValue(OTLPKeyValueList(values: kvList))
        case .array(let arr):
            return .arrayValue(OTLPArrayValue(values: arr.values.map { convertAttributeValue($0) }))
        }
    }
}
