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

// swiftlint:disable type_body_length

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

    // MARK: - Private Types

    /// Key for grouping metrics by scope within a resource.
    ///
    /// Uses scope name and version as the grouping key.
    private struct ScopeKey: Hashable {
        let name: String
        let version: String?

        init(from scope: InstrumentationScopeInfo?) {
            name = scope?.name ?? ""
            version = scope?.version
        }
    }


    // MARK: - Public Methods

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

            for (scopeKey, scopedMetrics) in groupedByScope {
                // Convert each MetricData to OTLPMetric
                let otlpMetrics = scopedMetrics.compactMap { convertMetric($0) }

                // Skip empty scope metrics (filter empty envelopes per OTLP spec)
                guard !otlpMetrics.isEmpty else {
                    continue
                }

                // Get the scope info from the first metric in this scope group
                let scopeInfo = scopedMetrics.first?.instrumentationScopeInfo

                let scopeMetrics = OTLPScopeMetrics(
                    scope: convertInstrumentationScope(scopeInfo),
                    metrics: otlpMetrics,
                    schemaUrl: scopeInfo?.schemaUrl
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


    // MARK: - Private Grouping Methods

    /// Groups metrics by resource.
    private static func groupByResource(_ metrics: [MetricData]) -> [Resource: [MetricData]] {
        var result: [Resource: [MetricData]] = [:]

        for metric in metrics {
            result[metric.resource, default: []].append(metric)
        }

        return result
    }

    /// Groups metrics by instrumentation scope within a resource.
    private static func groupByScope(_ metrics: [MetricData]) -> [ScopeKey: [MetricData]] {
        var result: [ScopeKey: [MetricData]] = [:]

        for metric in metrics {
            let key = ScopeKey(from: metric.instrumentationScopeInfo)
            result[key, default: []].append(metric)
        }

        return result
    }


    // MARK: - Private Conversion Methods

    // swiftlint:disable:next function_body_length

    /// Converts a MetricData to an OTLPMetric.
    ///
    /// Handles all metric types: Gauge, Sum, Histogram, Summary, ExponentialHistogram.
    /// Returns nil if the metric has no data points (empty metrics are filtered per OTLP spec).
    private static func convertMetric(_ metricData: MetricData) -> OTLPMetric? {
        let name = metricData.name
        let description = metricData.description.isEmpty ? nil : metricData.description
        let unit = metricData.unit.isEmpty ? nil : metricData.unit

        // Skip metrics with no data points
        guard !metricData.data.points.isEmpty else {
            return nil
        }

        switch metricData.type {
        case .LongGauge, .DoubleGauge:
            let dataPoints = convertNumberDataPoints(metricData.data.points, isLong: metricData.type == .LongGauge)
            guard !dataPoints.isEmpty else {
                return nil
            }
            return OTLPMetric(
                name: name,
                description: description,
                unit: unit,
                gauge: OTLPGauge(dataPoints: dataPoints)
            )

        case .LongSum, .DoubleSum:
            let dataPoints = convertNumberDataPoints(metricData.data.points, isLong: metricData.type == .LongSum)
            guard !dataPoints.isEmpty else {
                return nil
            }
            let temporality = convertAggregationTemporality(metricData.data.aggregationTemporality)
            return OTLPMetric(
                name: name,
                description: description,
                unit: unit,
                sum: OTLPSum(
                    dataPoints: dataPoints,
                    aggregationTemporality: temporality,
                    isMonotonic: metricData.isMonotonic
                )
            )

        case .Histogram:
            let dataPoints = convertHistogramDataPoints(metricData.data.points)
            guard !dataPoints.isEmpty else {
                return nil
            }
            let temporality = convertAggregationTemporality(metricData.data.aggregationTemporality)
            return OTLPMetric(
                name: name,
                description: description,
                unit: unit,
                histogram: OTLPHistogram(
                    dataPoints: dataPoints,
                    aggregationTemporality: temporality
                )
            )

        case .Summary:
            let dataPoints = convertSummaryDataPoints(metricData.data.points)
            guard !dataPoints.isEmpty else {
                return nil
            }
            return OTLPMetric(
                name: name,
                description: description,
                unit: unit,
                summary: OTLPSummary(dataPoints: dataPoints)
            )

        case .ExponentialHistogram:
            let dataPoints = convertExponentialHistogramDataPoints(metricData.data.points)
            guard !dataPoints.isEmpty else {
                return nil
            }
            let temporality = convertAggregationTemporality(metricData.data.aggregationTemporality)
            return OTLPMetric(
                name: name,
                description: description,
                unit: unit,
                exponentialHistogram: OTLPExponentialHistogram(
                    dataPoints: dataPoints,
                    aggregationTemporality: temporality
                )
            )
        }
    }

    /// Converts aggregation temporality to OTLP integer value.
    private static func convertAggregationTemporality(_ temporality: AggregationTemporality) -> Int {
        switch temporality {
        case .delta:
            return OTLPSum.aggregationTemporalityDelta

        case .cumulative:
            return OTLPSum.aggregationTemporalityCumulative
        }
    }

    /// Converts number data points (Long or Double) to OTLP NumberDataPoints.
    private static func convertNumberDataPoints(_ points: [PointData], isLong: Bool) -> [OTLPNumberDataPoint] {
        if isLong {
            // Cast to LongPointData and convert
            guard let longPoints = points as? [LongPointData] else {
                return []
            }
            return longPoints.map { point in
                OTLPNumberDataPoint(
                    attributes: convertAttributes(point.attributes),
                    startTimeUnixNano: OTLPUInt64(point.startEpochNanos),
                    timeUnixNano: OTLPUInt64(point.endEpochNanos),
                    asInt: OTLPInt64(Int64(point.value))
                )
            }
        }

        // Cast to DoublePointData and convert
        guard let doublePoints = points as? [DoublePointData] else {
            return []
        }
        return doublePoints.map { point in
            OTLPNumberDataPoint(
                attributes: convertAttributes(point.attributes),
                startTimeUnixNano: OTLPUInt64(point.startEpochNanos),
                timeUnixNano: OTLPUInt64(point.endEpochNanos),
                asDouble: point.value
            )
        }
    }

    /// Converts histogram data points to OTLP HistogramDataPoints.
    private static func convertHistogramDataPoints(_ points: [PointData]) -> [OTLPHistogramDataPoint] {
        guard let histogramPoints = points as? [HistogramPointData] else {
            return []
        }
        return histogramPoints.map { point in
            OTLPHistogramDataPoint(
                attributes: convertAttributes(point.attributes),
                startTimeUnixNano: OTLPUInt64(point.startEpochNanos),
                timeUnixNano: OTLPUInt64(point.endEpochNanos),
                count: OTLPUInt64(point.count),
                sum: point.sum,
                bucketCounts: point.counts.map { OTLPUInt64(UInt64($0)) },
                explicitBounds: point.boundaries,
                min: point.hasMin ? point.min : nil,
                max: point.hasMax ? point.max : nil
            )
        }
    }

    /// Converts summary data points to OTLP SummaryDataPoints.
    private static func convertSummaryDataPoints(_ points: [PointData]) -> [OTLPSummaryDataPoint] {
        guard let summaryPoints = points as? [SummaryPointData] else {
            return []
        }
        return summaryPoints.map { point in
            OTLPSummaryDataPoint(
                attributes: convertAttributes(point.attributes),
                startTimeUnixNano: OTLPUInt64(point.startEpochNanos),
                timeUnixNano: OTLPUInt64(point.endEpochNanos),
                count: OTLPUInt64(point.count),
                sum: point.sum,
                quantileValues: point.values.map { quantile in
                    OTLPQuantileValue(quantile: quantile.quantile, value: quantile.value)
                }
            )
        }
    }

    /// Converts exponential histogram data points to OTLP ExponentialHistogramDataPoints.
    private static func convertExponentialHistogramDataPoints(_ points: [PointData]) -> [OTLPExponentialHistogramDataPoint] {
        guard let expHistPoints = points as? [ExponentialHistogramPointData] else {
            return []
        }
        return expHistPoints.map { point in
            OTLPExponentialHistogramDataPoint(
                attributes: convertAttributes(point.attributes),
                startTimeUnixNano: OTLPUInt64(point.startEpochNanos),
                timeUnixNano: OTLPUInt64(point.endEpochNanos),
                count: OTLPUInt64(UInt64(point.count)),
                sum: point.sum,
                scale: Int32(point.scale),
                zeroCount: OTLPUInt64(UInt64(point.zeroCount)),
                positive: OTLPBuckets(
                    offset: Int32(point.positiveBuckets.offset),
                    bucketCounts: point.positiveBuckets.bucketCounts.map { OTLPUInt64(UInt64($0)) }
                ),
                negative: OTLPBuckets(
                    offset: Int32(point.negativeBuckets.offset),
                    bucketCounts: point.negativeBuckets.bucketCounts.map { OTLPUInt64(UInt64($0)) }
                ),
                min: point.hasMin ? point.min : nil,
                max: point.hasMax ? point.max : nil
            )
        }
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
        guard let scopeInfo else {
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
        case let .string(stringValue):
            return .stringValue(stringValue)

        case let .bool(boolValue):
            return .boolValue(boolValue)

        case let .int(intValue):
            return .intValue(Int64(intValue))

        case let .double(doubleValue):
            return .doubleValue(doubleValue)

        case let .stringArray(arr):
            return .arrayValue(OTLPArrayValue(values: arr.map { .stringValue($0) }))

        case let .boolArray(arr):
            return .arrayValue(OTLPArrayValue(values: arr.map { .boolValue($0) }))

        case let .intArray(arr):
            return .arrayValue(OTLPArrayValue(values: arr.map { .intValue(Int64($0)) }))

        case let .doubleArray(arr):
            return .arrayValue(OTLPArrayValue(values: arr.map { .doubleValue($0) }))

        case let .set(set):
            let kvList = set.labels.map { key, attrValue in
                OTLPKeyValue(key: key, value: convertAttributeValue(attrValue))
            }
            return .kvlistValue(OTLPKeyValueList(values: kvList))

        case let .array(arr):
            return .arrayValue(OTLPArrayValue(values: arr.values.map { convertAttributeValue($0) }))
        }
    }
}

// swiftlint:enable type_body_length
