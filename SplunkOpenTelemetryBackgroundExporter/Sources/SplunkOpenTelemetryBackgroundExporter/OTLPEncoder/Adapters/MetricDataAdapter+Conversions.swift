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

import OpenTelemetryApi
import OpenTelemetrySdk

extension MetricDataAdapter {

    // MARK: - Private Conversion Methods

    // swiftlint:disable cyclomatic_complexity
    // swiftlint:disable function_body_length

    /// Converts a MetricData to an OTLPMetric.
    ///
    /// Handles all metric types: Gauge, Sum, Histogram, Summary, ExponentialHistogram.
    /// Returns nil if the metric has no data points (empty metrics are filtered per OTLP spec).
    static func convertMetric(_ metricData: MetricData) -> OTLPMetric? {
        let name = metricData.name
        let description = metricData.description.isEmpty ? nil : metricData.description
        let unit = metricData.unit.isEmpty ? nil : metricData.unit

        // Skip metrics with no data points
        guard !metricData.data.points.isEmpty else {
            return nil
        }

        switch metricData.type {
        case .DoubleGauge,
            .LongGauge:
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

        case .DoubleSum,
            .LongSum:
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

    // swiftlint:enable cyclomatic_complexity
    // swiftlint:enable function_body_length

    /// Converts aggregation temporality to OTLP integer value.
    static func convertAggregationTemporality(_ temporality: AggregationTemporality) -> Int {
        switch temporality {
        case .delta:
            return OTLPSum.aggregationTemporalityDelta

        case .cumulative:
            return OTLPSum.aggregationTemporalityCumulative
        }
    }

    /// Converts number data points (Long or Double) to OTLP NumberDataPoints.
    static func convertNumberDataPoints(_ points: [PointData], isLong: Bool) -> [OTLPNumberDataPoint] {
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
    static func convertHistogramDataPoints(_ points: [PointData]) -> [OTLPHistogramDataPoint] {
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
    static func convertSummaryDataPoints(_ points: [PointData]) -> [OTLPSummaryDataPoint] {
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
    static func convertExponentialHistogramDataPoints(_ points: [PointData]) -> [OTLPExponentialHistogramDataPoint] {
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
    static func convertResource(_ resource: Resource) -> OTLPResource {
        OTLPResource(
            attributes: convertAttributes(resource.attributes) ?? [],
            droppedAttributesCount: nil
        )
    }

    /// Converts InstrumentationScopeInfo to OTLPInstrumentationScope.
    static func convertInstrumentationScope(_ scopeInfo: InstrumentationScopeInfo?) -> OTLPInstrumentationScope? {
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
    static func convertAttributes(_ attributes: [String: AttributeValue]) -> [OTLPKeyValue]? {
        guard !attributes.isEmpty else {
            return nil
        }

        return attributes.map { key, value in
            OTLPKeyValue(key: key, value: convertAttributeValue(value))
        }
    }

    /// Converts an AttributeValue to OTLPAnyValue.
    static func convertAttributeValue(_ value: AttributeValue) -> OTLPAnyValue {
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
