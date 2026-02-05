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

// MARK: - LogRecordAdapter

/// Adapter for converting OpenTelemetry SDK ReadableLogRecord to OTLP JSON models.
///
/// This adapter handles:
/// - Grouping log records by resource and instrumentation scope
/// - Converting ReadableLogRecord to OTLPLogRecord with proper encoding
/// - Filtering out empty envelopes per OTLP spec
///
/// NOTE: This adapter does NOT include an eventName field because eventName
/// is not part of the OTLP proto specification.
///
/// Based on OTLP specification v1.9.0.
enum LogRecordAdapter {

    // MARK: - Private Types

    /// Key for grouping log records by scope within a resource.
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

    /// Converts a list of ReadableLogRecord to OTLP ResourceLogs.
    ///
    /// Groups log records by resource and instrumentation scope, then converts them to
    /// OTLP JSON models. Empty envelopes are filtered out.
    ///
    /// - Parameter logRecords: The list of ReadableLogRecord to convert.
    /// - Returns: A list of OTLPResourceLogs (non-empty).
    static func toResourceLogs(_ logRecords: [ReadableLogRecord]) -> [OTLPResourceLogs] {
        // Group log records by resource first
        let groupedByResource = groupByResource(logRecords)

        var resourceLogsList: [OTLPResourceLogs] = []

        for (resource, logRecordList) in groupedByResource {
            // Group log records within this resource by scope
            let groupedByScope = groupByScope(logRecordList)

            var scopeLogsList: [OTLPScopeLogs] = []

            for (_, scopedLogs) in groupedByScope {
                // Convert each ReadableLogRecord to OTLPLogRecord
                let otlpLogRecords = scopedLogs.map { convertLogRecord($0) }

                // Skip empty scope logs (filter empty envelopes per OTLP spec)
                guard !otlpLogRecords.isEmpty else {
                    continue
                }

                // Get the scope info from the first log in this scope group
                let scopeInfo = scopedLogs.first?.instrumentationScopeInfo

                let scopeLogs = OTLPScopeLogs(
                    scope: convertInstrumentationScope(scopeInfo),
                    logRecords: otlpLogRecords,
                    schemaUrl: scopeInfo?.schemaUrl
                )
                scopeLogsList.append(scopeLogs)
            }

            // Skip empty resource logs (filter empty envelopes per OTLP spec)
            guard !scopeLogsList.isEmpty else {
                continue
            }

            let resourceLogs = OTLPResourceLogs(
                resource: convertResource(resource),
                scopeLogs: scopeLogsList,
                schemaUrl: nil // Resource.schemaUrl not available in current SDK version
            )
            resourceLogsList.append(resourceLogs)
        }

        return resourceLogsList
    }


    // MARK: - Private Grouping Methods

    /// Groups log records by resource.
    private static func groupByResource(_ logRecords: [ReadableLogRecord]) -> [Resource: [ReadableLogRecord]] {
        var result: [Resource: [ReadableLogRecord]] = [:]

        for logRecord in logRecords {
            result[logRecord.resource, default: []].append(logRecord)
        }

        return result
    }

    /// Groups log records by instrumentation scope within a resource.
    private static func groupByScope(_ logRecords: [ReadableLogRecord]) -> [ScopeKey: [ReadableLogRecord]] {
        var result: [ScopeKey: [ReadableLogRecord]] = [:]

        for logRecord in logRecords {
            let key = ScopeKey(from: logRecord.instrumentationScopeInfo)
            result[key, default: []].append(logRecord)
        }

        return result
    }


    // MARK: - Private Conversion Methods

    /// Converts a ReadableLogRecord to an OTLPLogRecord.
    private static func convertLogRecord(_ logRecord: ReadableLogRecord) -> OTLPLogRecord {
        // Get observed timestamp (required)
        let observedTimeNano: UInt64
        if let observedTimestamp = logRecord.observedTimestamp {
            observedTimeNano = observedTimestamp.timeIntervalSince1970.toNanoseconds
        }
        else {
            // Use timestamp as fallback if observedTimestamp is not set
            observedTimeNano = logRecord.timestamp.timeIntervalSince1970.toNanoseconds
        }

        return OTLPLogRecord(
            timeUnixNano: OTLPUInt64(logRecord.timestamp.timeIntervalSince1970.toNanoseconds),
            observedTimeUnixNano: OTLPUInt64(observedTimeNano),
            severityNumber: logRecord.severity?.rawValue,
            severityText: logRecord.severity?.description,
            body: logRecord.body.map { convertAttributeValue($0) },
            attributes: convertAttributes(logRecord.attributes),
            droppedAttributesCount: nil, // SDK doesn't track this
            flags: logRecord.spanContext.map { UInt32($0.traceFlags.byte) },
            traceId: logRecord.spanContext.map { OTLPTraceId(from: $0.traceId) },
            spanId: logRecord.spanContext.map { OTLPSpanId(from: $0.spanId) }
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
