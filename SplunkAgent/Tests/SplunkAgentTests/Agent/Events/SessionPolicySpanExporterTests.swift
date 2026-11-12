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
        let proxy = SessionPolicyMockSpanExporter()
        let exporter = SessionPolicySpanExporter(proxy: proxy)

        let result = exporter.export(spans: [makeSpanData()], explicitTimeout: nil)

        #expect(result == .success)
        #expect(proxy.exportedSpans.isEmpty)
    }

    @Test
    func dropsNonGeneratedSessionIds() {
        let proxy = SessionPolicyMockSpanExporter()
        let exporter = SessionPolicySpanExporter(proxy: proxy)
        let rejected = [
            "",
            "undefined",
            "no-op",
            "00000000-0000-0000-0000-000000000000",
            // Right length, wrong alphabet.
            "0123456789ABCDEF0123456789ABCDEF",
            // Hexadecimal but too short.
            "0123456789abcdef"
        ]
        let spans = rejected.map { sessionID in
            makeSpanData(attributes: ["session.id": .string(sessionID)])
        }

        let result = exporter.export(spans: spans, explicitTimeout: nil)

        #expect(result == .success)
        #expect(proxy.exportedSpans.isEmpty)
    }

    @Test
    func exportsSpanCarryingAGeneratedSessionId() {
        let proxy = SessionPolicyMockSpanExporter()
        let exporter = SessionPolicySpanExporter(proxy: proxy)

        let result = exporter.export(
            spans: [makeSpanData(attributes: ["session.id": .string(Self.realSessionID)])],
            explicitTimeout: nil
        )

        #expect(result == .success)
        #expect(proxy.exportedSpans.count == 1)
        #expect(proxy.exportedSpans.first?.attributes["session.id"] == .string(Self.realSessionID))
    }

    /// A span is judged by the ID stamped at its start, not by its start time.
    @Test
    func exportsSpanStartedBeforeSession() {
        let proxy = SessionPolicyMockSpanExporter()
        let exporter = SessionPolicySpanExporter(proxy: proxy)

        let appStart = makeSpanData(
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
        let proxy = SessionPolicyMockSpanExporter()
        let exporter = SessionPolicySpanExporter(proxy: proxy)

        let eligible = makeSpanData(
            name: "kept",
            attributes: ["session.id": .string(Self.realSessionID)]
        )
        let sessionless = makeSpanData(name: "dropped")
        let placeholder = makeSpanData(name: "also-dropped", attributes: ["session.id": .string("")])

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
        let proxy = SessionPolicyMockSpanExporter()
        let exporter = SessionPolicySpanExporter(proxy: proxy)
        let span = makeSpanData(attributes: [
            "session.id": .string(Self.realSessionID),
            "custom": .string("preserved")
        ])

        _ = exporter.export(spans: [span], explicitTimeout: nil)

        #expect(proxy.exportedSpans.first?.attributes["custom"] == .string("preserved"))
        #expect(proxy.exportedSpans.first?.attributes.count == span.attributes.count)
    }

    @Test
    func reportsDownstreamFailure() {
        let proxy = SessionPolicyMockSpanExporter()
        proxy.results = [.failure]
        let exporter = SessionPolicySpanExporter(proxy: proxy)

        let result = exporter.export(
            spans: [makeSpanData(attributes: ["session.id": .string(Self.realSessionID)])],
            explicitTimeout: nil
        )

        #expect(result == .failure)
    }

    /// A batch that lost spans still reports the downstream result for the spans it kept.
    @Test
    func reportsDownstreamFailureForAMixedBatch() {
        let proxy = SessionPolicyMockSpanExporter()
        proxy.results = [.failure]
        let exporter = SessionPolicySpanExporter(proxy: proxy)
        let eligible = makeSpanData(
            name: "kept",
            attributes: ["session.id": .string(Self.realSessionID)]
        )

        let result = exporter.export(spans: [makeSpanData(name: "dropped"), eligible], explicitTimeout: nil)

        #expect(result == .failure)
        #expect(proxy.exportedSpans.map(\.name) == ["kept"])
    }

    /// With debug logging on, a batch that lost spans logs its drop count once; a batch with no drop logs nothing.
    @Test
    func logsDroppedCountPerBatchWhenDebugOn() {
        let proxy = SessionPolicyMockSpanExporter()
        let recorder = DroppedCountRecorder()
        let exporter = SessionPolicySpanExporter(proxy: proxy, debugEnabled: true, logDroppedCount: recorder.record)
        let eligible = makeSpanData(attributes: ["session.id": .string(Self.realSessionID)])
        let placeholder = makeSpanData(attributes: ["session.id": .string("")])

        _ = exporter.export(spans: [makeSpanData(), eligible, placeholder], explicitTimeout: nil)
        _ = exporter.export(spans: [eligible], explicitTimeout: nil)
        _ = exporter.export(spans: [makeSpanData()], explicitTimeout: nil)

        #expect(recorder.counts == [2, 1])
        #expect(proxy.exportedSpans.count == 2)
    }

    @Test
    func logsNothingWhenDebugLoggingIsOff() {
        let recorder = DroppedCountRecorder()
        let exporter = SessionPolicySpanExporter(
            proxy: SessionPolicyMockSpanExporter(),
            debugEnabled: false,
            logDroppedCount: recorder.record
        )

        _ = exporter.export(
            spans: [makeSpanData(), makeSpanData(attributes: ["session.id": .string("")])],
            explicitTimeout: nil
        )

        #expect(recorder.counts.isEmpty)
    }

    private func makeSpanData(
        name: String = "test",
        startTime: Date = Date(),
        attributes: [String: AttributeValue] = [:]
    ) -> SpanData {
        let provider = TracerProviderBuilder().build()
        let tracer = provider.get(instrumentationName: "session-policy-tests")
        let span = tracer.spanBuilder(spanName: name)
            .setStartTime(time: startTime)
            .startSpan()

        for (key, value) in attributes {
            span.setAttribute(key: key, value: value)
        }
        span.end(time: startTime.addingTimeInterval(0.1))

        guard let readableSpan = span as? ReadableSpan else {
            fatalError("Expected an SDK readable span")
        }

        return readableSpan.toSpanData()
    }
}

private final class SessionPolicyMockSpanExporter: SpanExporter {
    private(set) var exportedSpans: [SpanData] = []

    /// Consumed in order; defaults to success once exhausted.
    var results: [SpanExporterResultCode] = []

    func export(spans: [SpanData], explicitTimeout _: TimeInterval?) -> SpanExporterResultCode {
        exportedSpans.append(contentsOf: spans)

        guard !results.isEmpty else {
            return .success
        }

        return results.removeFirst()
    }

    func flush(explicitTimeout _: TimeInterval?) -> SpanExporterResultCode {
        .success
    }

    func shutdown(explicitTimeout _: TimeInterval?) {}
}

private final class DroppedCountRecorder {
    private(set) var counts: [Int] = []

    func record(_ count: Int) {
        counts.append(count)
    }
}
