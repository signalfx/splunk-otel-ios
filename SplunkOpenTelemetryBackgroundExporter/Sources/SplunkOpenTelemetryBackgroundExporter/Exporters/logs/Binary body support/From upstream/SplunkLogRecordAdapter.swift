// swiftlint:disable file_header

// Changes made:
// - prefix filename
// - prefix class name
// - import import OpenTelemetryProtocolExporterCommon
// - use SplunkReadableLogRecord instead of ReadableLogRecord
// - use SplunkCommonAdapter instead of CommonAdapter
// - class and methods internal
// - copy TraceProtoUtils and rename to SplunkTraceProtoUtils
// - disable linters

//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi
import OpenTelemetryProtocolExporterCommon
import OpenTelemetrySdk

class SplunkLogRecordAdapter {
    static func toProtoResourceRecordLog(logRecordList: [SplunkReadableLogRecord]) -> [Opentelemetry_Proto_Logs_V1_ResourceLogs] {
        let resourceAndScopeMap = groupByResourceAndScope(logRecordList: logRecordList)
        var resourceLogs: [Opentelemetry_Proto_Logs_V1_ResourceLogs] = []
        for resMap in resourceAndScopeMap {
            var scopeLogs: [Opentelemetry_Proto_Logs_V1_ScopeLogs] = []
            for (scopeInfo, logRecords) in resMap.value {
                var protoScopeLogs = Opentelemetry_Proto_Logs_V1_ScopeLogs()
                protoScopeLogs.scope = SplunkCommonAdapter.toProtoInstrumentationScope(instrumentationScopeInfo: scopeInfo)
                for record in logRecords {
                    protoScopeLogs.logRecords.append(record)
                }
                scopeLogs.append(protoScopeLogs)
            }
            var resourceLog = Opentelemetry_Proto_Logs_V1_ResourceLogs()
            resourceLog.resource = ResourceAdapter.toProtoResource(resource: resMap.key)
            resourceLog.scopeLogs.append(contentsOf: scopeLogs)
            resourceLogs.append(resourceLog)
        }
        return resourceLogs
    }

    static func groupByResourceAndScope(
        logRecordList: [SplunkReadableLogRecord]
    ) -> [Resource: [InstrumentationScopeInfo: [Opentelemetry_Proto_Logs_V1_LogRecord]]] {
        var result: [Resource: [InstrumentationScopeInfo: [Opentelemetry_Proto_Logs_V1_LogRecord]]] = [:]
        for logRecord in logRecordList {
            result[logRecord.resource, default: [InstrumentationScopeInfo: [Opentelemetry_Proto_Logs_V1_LogRecord]]()][
                logRecord.instrumentationScopeInfo,
                default: [Opentelemetry_Proto_Logs_V1_LogRecord]()
            ]
            .append(toProtoLogRecord(logRecord: logRecord))
        }
        return result
    }

    static func toProtoLogRecord(logRecord: SplunkReadableLogRecord) -> Opentelemetry_Proto_Logs_V1_LogRecord {
        var protoLogRecord = Opentelemetry_Proto_Logs_V1_LogRecord()

        if let observedTimestamp = logRecord.observedTimestamp {
            protoLogRecord.observedTimeUnixNano = observedTimestamp.timeIntervalSince1970.toNanoseconds
        }

        protoLogRecord.timeUnixNano = logRecord.timestamp.timeIntervalSince1970.toNanoseconds

        if let body = logRecord.body {
            protoLogRecord.body = SplunkCommonAdapter.toProtoAnyValue(attributeValue: body)
        }

        if let severity = logRecord.severity {
            protoLogRecord.severityText = severity.description
            if let protoSeverity = Opentelemetry_Proto_Logs_V1_SeverityNumber(rawValue: severity.rawValue) {
                protoLogRecord.severityNumber = protoSeverity
            }
        }

        if let context = logRecord.spanContext {
            protoLogRecord.spanID = SplunkTraceProtoUtils.toProtoSpanId(spanId: context.spanId)
            protoLogRecord.traceID = SplunkTraceProtoUtils.toProtoTraceId(traceId: context.traceId)
            protoLogRecord.flags = UInt32(context.traceFlags.byte)
        }

        var protoAttributes: [Opentelemetry_Proto_Common_V1_KeyValue] = []
        for (key, value) in logRecord.attributes {
            protoAttributes.append(SplunkCommonAdapter.toProtoAttribute(key: key, attributeValue: value))
        }
        protoLogRecord.attributes = protoAttributes
        return protoLogRecord
    }
}

private enum SplunkTraceProtoUtils {
    static func toProtoSpanId(spanId: SpanId) -> Data {
        var spanIdData = Data(count: SpanId.size)
        spanId.copyBytesTo(dest: &spanIdData, destOffset: 0)
        return spanIdData
    }

    static func toProtoTraceId(traceId: TraceId) -> Data {
        var traceIdData = Data(count: TraceId.size)
        traceId.copyBytesTo(dest: &traceIdData, destOffset: 0)
        return traceIdData
    }
}
