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
import OpenTelemetrySdk
import Testing
@testable import SplunkOpenTelemetryBackgroundExporter

@Suite
struct SplunkReadableLogRecordTests {

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


    // MARK: - Init and stored properties

    @Test
    func initSetsAllFieldsCorrectly() throws {
        let res = makeResource("R1")
        let scope = makeScope("scope", version: "1.0.0")
        let ts = Date()
        let obs = ts.addingTimeInterval(0.25)
        let ctx = makeSpanContext()
        let attrs: [String: SplunkAttributeValue] = ["a": .string("v"), "n": .int(5)]
        let body: SplunkAttributeValue = .string("hello")

        let record = SplunkReadableLogRecord(
            resource: res,
            instrumentationScopeInfo: scope,
            timestamp: ts,
            observedTimestamp: obs,
            spanContext: ctx,
            severity: .warn,
            body: body,
            attributes: attrs
        )

        #expect(record.resource.attributes["res.label"]?.description == "R1")

        // Scope
        #expect(record.instrumentationScopeInfo.name == scope.name)
        #expect(record.instrumentationScopeInfo.version == scope.version)

        // Timestamps
        #expect(record.timestamp == ts)
        #expect(record.observedTimestamp == obs)

        // Span context (porovnáme Trace/Span ID jako Data)
        let recCtx = try #require(record.spanContext)
        #expect(dataFrom(traceId: recCtx.traceId) == dataFrom(traceId: ctx.traceId))
        #expect(dataFrom(spanId: recCtx.spanId) == dataFrom(spanId: ctx.spanId))

        // Severity
        #expect(record.severity == .warn)

        // Body
        #expect(record.body == .string("hello"))

        // Attributes
        #expect(record.attributes["a"] == .string("v"))
        #expect(record.attributes["n"] == .int(5))
    }

    @Test
    func initDefaultsOptionalFieldsToNil() {
        let record = SplunkReadableLogRecord(
            resource: makeResource("R2"),
            instrumentationScopeInfo: makeScope("s"),
            timestamp: Date(),
            attributes: [:]
        )

        #expect(record.observedTimestamp == nil)
        #expect(record.spanContext == nil)
        #expect(record.severity == nil)
        #expect(record.body == nil)
    }


    // MARK: - Mutability

    @Test
    func bodyAndAttributesAreMutable() {
        var record = SplunkReadableLogRecord(
            resource: makeResource("R3"),
            instrumentationScopeInfo: makeScope("s"),
            timestamp: Date(),
            attributes: ["k": .int(1)]
        )

        // Mutate body
        #expect(record.body == nil)
        record.body = .data(Data([0x00, 0xFF]))
        #expect(record.body == .data(Data([0x00, 0xFF])))

        // Mutate attributes
        record.attributes["k"] = .int(2)
        record.attributes["new"] = .string("v")
        #expect(record.attributes["k"] == .int(2))
        #expect(record.attributes["new"] == .string("v"))
    }


    // MARK: - Codable

    @Test
    func codableRoundTripWithoutOptionals() throws {
        let record = SplunkReadableLogRecord(
            resource: makeResource("R4"),
            instrumentationScopeInfo: makeScope("s", version: "2.0"),
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            attributes: ["a": .bool(true), "n": .double(3.5)]
        )

        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(SplunkReadableLogRecord.self, from: data)

        // Resource label
        #expect(decoded.resource.attributes["res.label"]?.description == "R4")

        // Scope
        #expect(decoded.instrumentationScopeInfo.name == "s")
        #expect(decoded.instrumentationScopeInfo.version == "2.0")

        // Timestamp
        #expect(decoded.timestamp == record.timestamp)

        // Attributes
        #expect(decoded.attributes["a"] == .bool(true))
        #expect(decoded.attributes["n"] == .double(3.5))

        // Optionals remain nil
        #expect(decoded.observedTimestamp == nil)
        #expect(decoded.spanContext == nil)
        #expect(decoded.severity == nil)
        #expect(decoded.body == nil)
    }

    @Test
    func codableRoundTripWithAllFieldsIncludingDataBodyAndSpanContext() throws {
        let res = makeResource("R5")
        let scope = makeScope("scope-x", version: "0.9")
        let ts = Date(timeIntervalSince1970: 1_700_000_100)
        let obs = ts.addingTimeInterval(0.123)
        let ctx = makeSpanContext()
        let bodyBytes = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let attrs: [String: SplunkAttributeValue] = [
            "s": .string("str"),
            "b": .bool(false),
            "i": .int(10),
            "d": .double(1.25),
            "bin": .data(Data([0xAA]))
        ]

        let record = SplunkReadableLogRecord(
            resource: res,
            instrumentationScopeInfo: scope,
            timestamp: ts,
            observedTimestamp: obs,
            spanContext: ctx,
            severity: .error,
            body: .data(bodyBytes),
            attributes: attrs
        )

        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(SplunkReadableLogRecord.self, from: data)

        // Resource label
        #expect(decoded.resource.attributes["res.label"]?.description == "R5")

        // Scope
        #expect(decoded.instrumentationScopeInfo.name == scope.name)
        #expect(decoded.instrumentationScopeInfo.version == scope.version)

        // Timestamps
        #expect(decoded.timestamp == ts)
        #expect(decoded.observedTimestamp == obs)

        // SpanContext IDs
        let dCtx = try #require(decoded.spanContext)
        #expect(dataFrom(traceId: dCtx.traceId) == dataFrom(traceId: ctx.traceId))
        #expect(dataFrom(spanId: dCtx.spanId) == dataFrom(spanId: ctx.spanId))

        // Severity
        #expect(decoded.severity == .error)

        // Body bytes
        #expect(decoded.body == .data(bodyBytes))

        // Attributes
        #expect(decoded.attributes["s"] == .string("str"))
        #expect(decoded.attributes["b"] == .bool(false))
        #expect(decoded.attributes["i"] == .int(10))
        #expect(decoded.attributes["d"] == .double(1.25))
        #expect(decoded.attributes["bin"] == .data(Data([0xAA])))
    }
}
