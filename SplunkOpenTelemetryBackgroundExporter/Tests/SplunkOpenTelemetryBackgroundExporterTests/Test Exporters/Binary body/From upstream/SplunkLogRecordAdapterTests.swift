//
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
import OpenTelemetryProtocolExporterCommon
import OpenTelemetrySdk
import Testing
@testable import SplunkOpenTelemetryBackgroundExporter

@Suite
struct SplunkLogRecordAdapterTests {

    // MARK: - Helpers

    func makeResource(_ label: String) -> Resource {
        Resource(attributes: ["res.label": .string(label)])
    }

    func makeScope(_ name: String, version: String? = nil) -> InstrumentationScopeInfo {
        InstrumentationScopeInfo(name: name, version: version)
    }

    func makeSpanContext() -> SpanContext {
        let traceId = TraceId.random()
        let spanId = SpanId.random()
        return SpanContext.create(traceId: traceId, spanId: spanId, traceFlags: TraceFlags(), traceState: TraceState())
    }

    func dataFrom(spanId: SpanId) -> Data {
        var out = Data(count: SpanId.size)
        spanId.copyBytesTo(dest: &out, destOffset: 0)
        return out
    }

    func dataFrom(traceId: TraceId) -> Data {
        var out = Data(count: TraceId.size)
        traceId.copyBytesTo(dest: &out, destOffset: 0)
        return out
    }


    // MARK: - toProtoLogRecord

    @Test
    func toProtoLogRecordMapsBasicFields() {
        let resource = makeResource("r1")
        let scope = makeScope("s1", version: "1.0.0")
        let ts = Date()
        let obs = ts.addingTimeInterval(0.5)
        let attributes: [String: SplunkAttributeValue] = [
            "a": .string("v"),
            "n": .int(7)
        ]

        var log = SplunkReadableLogRecord(
            resource: resource,
            instrumentationScopeInfo: scope,
            timestamp: ts,
            observedTimestamp: obs,
            spanContext: nil,
            severity: .info,
            body: .string("body"),
            attributes: attributes
        )

        // Ensure body is set explicitly (struct may be var)
        log.body = .string("body")

        let proto = SplunkLogRecordAdapter.toProtoLogRecord(logRecord: log)

        #expect(proto.timeUnixNano == ts.timeIntervalSince1970.toNanoseconds)
        #expect(proto.observedTimeUnixNano == obs.timeIntervalSince1970.toNanoseconds)

        // Severity text/number
        #expect(proto.severityText == Severity.info.description)
        #expect(proto.severityNumber.rawValue == Severity.info.rawValue)

        // Body string
        #expect(proto.body.stringValue == "body")

        // Attributes
        #expect(proto.attributes.count == 2)
        var dict: [String: Opentelemetry_Proto_Common_V1_AnyValue] = [:]
        for kv in proto.attributes {
            dict[kv.key] = kv.value
        }
        #expect(dict["a"]?.stringValue == "v")
        #expect(dict["n"]?.intValue == 7)
    }

    @Test
    func toProtoLogRecordMapsBodyData() {
        let resource = makeResource("r2")
        let scope = makeScope("s2")
        let ts = Date()
        let bytes = Data([0x00, 0xFF, 0x10])

        let log = SplunkReadableLogRecord(
            resource: resource,
            instrumentationScopeInfo: scope,
            timestamp: ts,
            observedTimestamp: nil,
            spanContext: nil,
            severity: .error,
            body: .data(bytes),
            attributes: [:]
        )

        let proto = SplunkLogRecordAdapter.toProtoLogRecord(logRecord: log)
        #expect(proto.body.bytesValue == bytes)
        #expect(proto.severityText == Severity.error.description)
        #expect(proto.severityNumber.rawValue == Severity.error.rawValue)
    }

    @Test
    func toProtoLogRecordMapsSpanContextAndFlags() {
        let ctx = makeSpanContext()

        let log = SplunkReadableLogRecord(
            resource: makeResource("r3"),
            instrumentationScopeInfo: makeScope("s3"),
            timestamp: Date(),
            observedTimestamp: nil,
            spanContext: ctx,
            severity: nil,
            body: nil,
            attributes: [:]
        )

        let proto = SplunkLogRecordAdapter.toProtoLogRecord(logRecord: log)

        #expect(proto.spanID == dataFrom(spanId: ctx.spanId))
        #expect(proto.traceID == dataFrom(traceId: ctx.traceId))
        #expect(proto.flags == UInt32(ctx.traceFlags.byte))
    }


    // MARK: - groupByResourceAndScope

    @Test
    func groupByResourceAndScopeGroupsCorrectly() {
        let r1 = makeResource("R-1")
        let r2 = makeResource("R-2")
        let s1 = makeScope("S-1")
        let s2 = makeScope("S-2")

        let l1 = SplunkReadableLogRecord(
            resource: r1,
            instrumentationScopeInfo: s1,
            timestamp: Date(),
            observedTimestamp: nil,
            spanContext: nil,
            severity: nil,
            body: nil,
            attributes: [:]
        )
        let l2 = SplunkReadableLogRecord(
            resource: r1,
            instrumentationScopeInfo: s1,
            timestamp: Date().addingTimeInterval(0.1),
            observedTimestamp: nil,
            spanContext: nil,
            severity: nil,
            body: nil,
            attributes: [:]
        )
        let l3 = SplunkReadableLogRecord(
            resource: r2,
            instrumentationScopeInfo: s2,
            timestamp: Date().addingTimeInterval(0.2),
            observedTimestamp: nil,
            spanContext: nil,
            severity: nil,
            body: nil,
            attributes: [:]
        )

        let grouped = SplunkLogRecordAdapter.groupByResourceAndScope(logRecordList: [l1, l2, l3])

        #expect(grouped.keys.count == 2)

        let r1Scopes = grouped[r1]
        let r1s1 = r1Scopes?[s1]
        #expect(r1s1?.count == 2)

        let r2Scopes = grouped[r2]
        let r2s2 = r2Scopes?[s2]
        #expect(r2s2?.count == 1)
    }


    // MARK: - toProtoResourceRecordLog

    @Test
    func toProtoResourceRecordLogBuildsResourceAndScopeLogs() throws {
        let r1 = makeResource("R-A")
        let r2 = makeResource("R-B")
        let s1 = makeScope("scope-A", version: "0.1")
        let s2 = makeScope("scope-B", version: "0.2")

        let l1 = SplunkReadableLogRecord(
            resource: r1,
            instrumentationScopeInfo: s1,
            timestamp: Date(),
            observedTimestamp: nil,
            spanContext: nil,
            severity: .debug,
            body: .string("a"),
            attributes: ["k": .int(1)]
        )
        let l2 = SplunkReadableLogRecord(
            resource: r1,
            instrumentationScopeInfo: s2,
            timestamp: Date().addingTimeInterval(0.1),
            observedTimestamp: nil,
            spanContext: nil,
            severity: .info,
            body: .string("b"),
            attributes: ["k": .int(2)]
        )
        let l3 = SplunkReadableLogRecord(
            resource: r2,
            instrumentationScopeInfo: s2,
            timestamp: Date().addingTimeInterval(0.2),
            observedTimestamp: nil,
            spanContext: nil,
            severity: .warn,
            body: .string("c"),
            attributes: ["k": .int(3)]
        )

        let resourceLogs = SplunkLogRecordAdapter.toProtoResourceRecordLog(logRecordList: [l1, l2, l3])

        #expect(resourceLogs.count == 2)

        let rlA = try #require(resourceLogs.first { resourceLabel($0) == "R-A" })
        let rlB = try #require(resourceLogs.first { resourceLabel($0) == "R-B" })

        #expect(rlA.scopeLogs.count == 2)
        #expect(rlB.scopeLogs.count == 1)

        let slA = try #require(rlA.scopeLogs.first { $0.scope.name == s1.name && $0.scope.version == s1.version })
        #expect(slA.logRecords.count == 1)
        #expect(slA.logRecords.first?.body.stringValue == "a")

        let slBA = try #require(rlA.scopeLogs.first { $0.scope.name == s2.name && $0.scope.version == s2.version })
        #expect(slBA.logRecords.count == 1)
        #expect(slBA.logRecords.first?.body.stringValue == "b")

        let slBB = try #require(rlB.scopeLogs.first { $0.scope.name == s2.name && $0.scope.version == s2.version })
        #expect(slBB.logRecords.count == 1)
        #expect(slBB.logRecords.first?.body.stringValue == "c")
    }

    func resourceLabel(_ rl: Opentelemetry_Proto_Logs_V1_ResourceLogs) -> String? {
        for kv in rl.resource.attributes where kv.key == "res.label" {
            return kv.value.stringValue
        }
        return nil
    }
}
