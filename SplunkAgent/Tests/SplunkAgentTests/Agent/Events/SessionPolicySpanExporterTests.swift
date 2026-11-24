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
import Testing

@testable import SplunkOpenTelemetry

@Suite
struct SessionPolicySpanExporterTests {
    private static let realSessionID = "0123456789abcdef0123456789abcdef"

    @Test
    func dropsSpanCarryingNoSessionId() {
        let proxy = MockSpanExporter()
        let exporter = SessionPolicySpanExporter(proxy: proxy)

        // No session existed when the span was created, so the attributes processor omitted the key.
        let result = exporter.export(spans: [SpanDataTestBuilder.build()], explicitTimeout: nil)

        #expect(result == .success)
        #expect(proxy.exportedSpans.isEmpty)
    }

    @Test
    func dropsNonGeneratedSessionIds() {
        let proxy = MockSpanExporter()
        let exporter = SessionPolicySpanExporter(proxy: proxy)
        let rejected: [AttributeValue] = [
            .string(""),
            .string("undefined"),
            .string("no-op"),
            .string("00000000-0000-0000-0000-000000000000"),
            // Right length, wrong alphabet.
            .string("0123456789ABCDEF0123456789ABCDEF"),
            // Right length, one character outside the hexadecimal alphabet.
            .string("0123456789abcdef0123456789abcdeg"),
            // Hexadecimal but too short.
            .string("0123456789abcdef"),
            // Hexadecimal but one character too long.
            .string("0123456789abcdef0123456789abcdef0"),
            // Not a string.
            .int(1)
        ]
        let spans = rejected.map { sessionID in
            SpanDataTestBuilder.build(attributes: ["session.id": sessionID])
        }

        let result = exporter.export(spans: spans, explicitTimeout: nil)

        #expect(result == .success)
        #expect(proxy.exportedSpans.isEmpty)
    }

    @Test
    func exportsSpanCarryingAGeneratedSessionId() {
        let proxy = MockSpanExporter()
        let exporter = SessionPolicySpanExporter(proxy: proxy)

        let result = exporter.export(
            spans: [SpanDataTestBuilder.build(attributes: ["session.id": .string(Self.realSessionID)])],
            explicitTimeout: nil
        )

        #expect(result == .success)
        #expect(proxy.exportedSpans.count == 1)
        #expect(proxy.exportedSpans.first?.attributes["session.id"] == .string(Self.realSessionID))
    }

    /// A span is judged by the ID stamped at its start, not by its start time.
    @Test
    func exportsSpanStartedBeforeSession() {
        let proxy = MockSpanExporter()
        let exporter = SessionPolicySpanExporter(proxy: proxy)

        let appStart = SpanDataTestBuilder.build(
            name: "AppStart",
            startTime: Date().addingTimeInterval(-30),
            attributes: ["session.id": .string(Self.realSessionID)]
        )

        let result = exporter.export(spans: [appStart], explicitTimeout: nil)

        #expect(result == .success)
        #expect(proxy.exportedSpans.count == 1)
        #expect(proxy.exportedSpans.first?.startTime == appStart.startTime)
    }

    @Test
    func keepsOnlyEligibleSpansFromAMixedBatch() {
        let proxy = MockSpanExporter()
        let exporter = SessionPolicySpanExporter(proxy: proxy)

        let eligible = SpanDataTestBuilder.build(
            name: "kept",
            attributes: ["session.id": .string(Self.realSessionID)]
        )
        let sessionless = SpanDataTestBuilder.build(name: "dropped")
        let placeholder = SpanDataTestBuilder.build(name: "also-dropped", attributes: ["session.id": .string("")])

        let result = exporter.export(
            spans: [sessionless, eligible, placeholder],
            explicitTimeout: nil
        )

        #expect(result == .success)
        #expect(proxy.exportedSpans.map(\.name) == ["kept"])
    }

    /// The stage does not rewrite attributes, so an eligible span reaches the proxy untouched.
    @Test
    func doesNotRewriteAnEligibleSpansAttributes() {
        let proxy = MockSpanExporter()
        let exporter = SessionPolicySpanExporter(proxy: proxy)
        let span = SpanDataTestBuilder.build(attributes: [
            "session.id": .string(Self.realSessionID),
            "custom": .string("preserved")
        ])

        _ = exporter.export(spans: [span], explicitTimeout: nil)

        #expect(proxy.exportedSpans.first?.attributes["custom"] == .string("preserved"))
        #expect(proxy.exportedSpans.first?.attributes.count == span.attributes.count)
    }

    @Test
    func reportsDownstreamFailure() {
        let proxy = MockSpanExporter()
        proxy.results = [.failure]
        let exporter = SessionPolicySpanExporter(proxy: proxy)

        let result = exporter.export(
            spans: [SpanDataTestBuilder.build(attributes: ["session.id": .string(Self.realSessionID)])],
            explicitTimeout: nil
        )

        #expect(result == .failure)
    }

    /// A batch that lost spans still reports the downstream result for the spans it kept.
    @Test
    func reportsDownstreamFailureForAMixedBatch() {
        let proxy = MockSpanExporter()
        proxy.results = [.failure]
        let exporter = SessionPolicySpanExporter(proxy: proxy)
        let eligible = SpanDataTestBuilder.build(
            name: "kept",
            attributes: ["session.id": .string(Self.realSessionID)]
        )

        let result = exporter.export(spans: [SpanDataTestBuilder.build(name: "dropped"), eligible], explicitTimeout: nil)

        #expect(result == .failure)
        #expect(proxy.exportedSpans.map(\.name) == ["kept"])
    }

    /// With debug logging on, a batch that lost spans logs its drop count once; a batch with no drop logs nothing.
    @Test
    func logsDroppedCountPerBatchWhenDebugOn() {
        let proxy = MockSpanExporter()
        let recorder = DroppedCountRecorder()
        let exporter = SessionPolicySpanExporter(proxy: proxy, debugEnabled: true, logDroppedCount: recorder.record)
        let eligible = SpanDataTestBuilder.build(attributes: ["session.id": .string(Self.realSessionID)])
        let placeholder = SpanDataTestBuilder.build(attributes: ["session.id": .string("")])

        _ = exporter.export(spans: [SpanDataTestBuilder.build(), eligible, placeholder], explicitTimeout: nil)
        _ = exporter.export(spans: [eligible], explicitTimeout: nil)
        _ = exporter.export(spans: [SpanDataTestBuilder.build()], explicitTimeout: nil)

        #expect(recorder.counts == [2, 1])
        #expect(proxy.exportedSpans.count == 2)
    }

    @Test
    func logsNothingWhenDebugLoggingIsOff() {
        let recorder = DroppedCountRecorder()
        let exporter = SessionPolicySpanExporter(
            proxy: MockSpanExporter(),
            debugEnabled: false,
            logDroppedCount: recorder.record
        )

        _ = exporter.export(
            spans: [SpanDataTestBuilder.build(), SpanDataTestBuilder.build(attributes: ["session.id": .string("")])],
            explicitTimeout: nil
        )

        #expect(recorder.counts.isEmpty)
    }
}
