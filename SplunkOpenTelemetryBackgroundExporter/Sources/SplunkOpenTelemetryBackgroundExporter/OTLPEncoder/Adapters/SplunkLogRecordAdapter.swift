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


// MARK: - SplunkLogRecordAdapterJSON

/// Adapter for converting SplunkReadableLogRecord (with binary body support) to OTLP JSON models.
///
/// This adapter is specifically designed for Session Replay which requires binary data
/// in the log record body. Binary data is encoded as base64 per OTLP JSON specification.
///
/// Key differences from standard LogRecordAdapter:
/// - Uses SplunkReadableLogRecord instead of ReadableLogRecord
/// - Uses SplunkAttributeValue which includes a .data case for binary data
/// - Encodes binary body data as base64 via OTLPAnyValue.bytesValue
///
/// Based on OTLP specification v1.9.0.
enum SplunkLogRecordAdapterJSON {

    // MARK: - Private Types

    /// Key for grouping log records by scope within a resource.
    /// Uses scope name and version as the grouping key.
    private struct ScopeKey: Hashable {
        let name: String
        let version: String?

        init(from scope: InstrumentationScopeInfo?) {
            self.name = scope?.name ?? ""
            self.version = scope?.version
        }
    }


    // MARK: - Public Methods

    /// Converts a list of SplunkReadableLogRecord to OTLP ResourceLogs.
    ///
    /// Groups log records by resource and instrumentation scope, then converts them to
    /// OTLP JSON models. Empty envelopes are filtered out.
    ///
    /// - Parameter logRecords: The list of SplunkReadableLogRecord to convert.
    /// - Returns: A list of OTLPResourceLogs (non-empty).
    static func toResourceLogs(_ logRecords: [SplunkReadableLogRecord]) -> [OTLPResourceLogs] {
        // Group log records by resource first
        let groupedByResource = groupByResource(logRecords)

        var resourceLogsList: [OTLPResourceLogs] = []

        for (resource, logRecordList) in groupedByResource {
            // Group log records within this resource by scope
            let groupedByScope = groupByScope(logRecordList)

            var scopeLogsList: [OTLPScopeLogs] = []

            for (scopeKey, scopedLogs) in groupedByScope {
                // Convert each SplunkReadableLogRecord to OTLPLogRecord
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
                schemaUrl: nil  // Resource.schemaUrl not available in current SDK version
            )
            resourceLogsList.append(resourceLogs)
        }

        return resourceLogsList
    }


    // MARK: - Private Grouping Methods

    /// Groups log records by resource.
    private static func groupByResource(_ logRecords: [SplunkReadableLogRecord]) -> [Resource: [SplunkReadableLogRecord]] {
        var result: [Resource: [SplunkReadableLogRecord]] = [:]

        for logRecord in logRecords {
            result[logRecord.resource, default: []].append(logRecord)
        }

        return result
    }

    /// Groups log records by instrumentation scope within a resource.
    private static func groupByScope(_ logRecords: [SplunkReadableLogRecord]) -> [ScopeKey: [SplunkReadableLogRecord]] {
        var result: [ScopeKey: [SplunkReadableLogRecord]] = [:]

        for logRecord in logRecords {
            let key = ScopeKey(from: logRecord.instrumentationScopeInfo)
            result[key, default: []].append(logRecord)
        }

        return result
    }


    // MARK: - Private Conversion Methods

    /// Converts a SplunkReadableLogRecord to an OTLPLogRecord.
    private static func convertLogRecord(_ logRecord: SplunkReadableLogRecord) -> OTLPLogRecord {
        // Get observed timestamp (required)
        let observedTimeNano: UInt64
        if let observedTimestamp = logRecord.observedTimestamp {
            observedTimeNano = observedTimestamp.timeIntervalSince1970.toNanoseconds
        } else {
            // Use timestamp as fallback if observedTimestamp is not set
            observedTimeNano = logRecord.timestamp.timeIntervalSince1970.toNanoseconds
        }

        return OTLPLogRecord(
            timeUnixNano: OTLPUInt64(logRecord.timestamp.timeIntervalSince1970.toNanoseconds),
            observedTimeUnixNano: OTLPUInt64(observedTimeNano),
            severityNumber: logRecord.severity?.rawValue,
            severityText: logRecord.severity?.description,
            // Body may contain binary data - will be encoded as base64
            body: logRecord.body.map { convertSplunkAttributeValue($0) },
            attributes: convertSplunkAttributes(logRecord.attributes),
            droppedAttributesCount: nil,
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
    /// This version handles standard AttributeValue from Resource.
    private static func convertAttributes(_ attributes: [String: AttributeValue]) -> [OTLPKeyValue]? {
        guard !attributes.isEmpty else {
            return nil
        }
        return attributes.map { key, value in
            OTLPKeyValue(key: key, value: convertAttributeValue(value))
        }
    }

    /// Converts SplunkAttributeValue attributes dictionary to array of OTLPKeyValue.
    /// This version handles SplunkAttributeValue which includes binary data support.
    private static func convertSplunkAttributes(_ attributes: [String: SplunkAttributeValue]) -> [OTLPKeyValue]? {
        guard !attributes.isEmpty else {
            return nil
        }
        return attributes.map { key, value in
            OTLPKeyValue(key: key, value: convertSplunkAttributeValue(value))
        }
    }

    /// Converts a standard AttributeValue to OTLPAnyValue.
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

    /// Converts a SplunkAttributeValue to OTLPAnyValue.
    ///
    /// This method handles the additional .data case for binary data, which will be
    /// encoded as base64 in the JSON output via OTLPAnyValue.bytesValue.
    private static func convertSplunkAttributeValue(_ value: SplunkAttributeValue) -> OTLPAnyValue {
        switch value {
        case .string(let v):
            return .stringValue(v)
        case .bool(let v):
            return .boolValue(v)
        case .int(let v):
            return .intValue(Int64(v))
        case .double(let v):
            return .doubleValue(v)
        case .data(let v):
            // Binary data - will be encoded as base64 in JSON
            return .bytesValue(v)
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
                OTLPKeyValue(key: key, value: convertSplunkAttributeValue(SplunkAttributeValue(otelAttributeValue: attrValue)))
            }
            return .kvlistValue(OTLPKeyValueList(values: kvList))
        case .array(let arr):
            let values = arr.values.map { attrValue in
                convertSplunkAttributeValue(SplunkAttributeValue(otelAttributeValue: attrValue))
            }
            return .arrayValue(OTLPArrayValue(values: values))
        }
    }
}
