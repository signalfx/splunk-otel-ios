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
import SplunkCommon
import Testing

@testable import SplunkOpenTelemetry

/// A span is exported only if the agent assigned its session ID and the customer span interceptor
/// left that ID unchanged.
@Suite
struct SessionIdInterceptorPolicyTests {
    private static let sessionId = "0123456789abcdef0123456789abcdef"
    private static let otherSessionId = "fedcba9876543210fedcba9876543210"


    // MARK: - Interceptor

    @Test
    func dropsSessionlessSpanBeforeInterceptor() {
        let recorder = MockSpanExporter()
        var interceptedNames: [String] = []
        let pipeline = SessionPolicyPipelineTestBuilder.buildExportChain(proxy: recorder) { span in
            interceptedNames.append(span.name)
            var span = span
            return span.settingAttributes(span.attributes.merging(["session.id": .string(Self.sessionId)]) { _, new in new })
        }

        _ = pipeline.export(spans: [SpanDataTestBuilder.build(name: "sessionless")], explicitTimeout: nil)

        #expect(interceptedNames.isEmpty)
        #expect(recorder.exportedSpans.isEmpty)
    }

    @Test
    func dropsSpanInterceptorReplacedId() {
        let recorder = MockSpanExporter()
        let pipeline = SessionPolicyPipelineTestBuilder.buildExportChain(proxy: recorder) { span in
            var span = span
            return span.settingAttributes(span.attributes.merging(["session.id": .string(Self.otherSessionId)]) { _, new in new })
        }

        let result = pipeline.export(
            spans: [SpanDataTestBuilder.build(attributes: ["session.id": .string(Self.sessionId)])],
            explicitTimeout: nil
        )

        #expect(result == .success)
        #expect(recorder.exportedSpans.isEmpty)
    }

    @Test
    func dropsSpanInterceptorRemovedId() {
        let recorder = MockSpanExporter()
        let pipeline = SessionPolicyPipelineTestBuilder.buildExportChain(proxy: recorder) { span in
            var attributes = span.attributes
            attributes["session.id"] = nil
            var span = span
            return span.settingAttributes(attributes)
        }

        _ = pipeline.export(
            spans: [SpanDataTestBuilder.build(attributes: ["session.id": .string(Self.sessionId)])],
            explicitTimeout: nil
        )

        #expect(recorder.exportedSpans.isEmpty)
    }

    @Test
    func exportsSpanInterceptorLeftAlone() {
        let recorder = MockSpanExporter()
        let pipeline = SessionPolicyPipelineTestBuilder.buildExportChain(proxy: recorder) { span in
            var span = span
            return span.settingAttributes(span.attributes.merging(["custom": .string("added")]) { _, new in new })
        }

        _ = pipeline.export(
            spans: [SpanDataTestBuilder.build(attributes: ["session.id": .string(Self.sessionId)])],
            explicitTimeout: nil
        )

        #expect(recorder.exportedSpans.count == 1)
        #expect(recorder.exportedSpans.first?.attributes["session.id"] == .string(Self.sessionId))
        #expect(recorder.exportedSpans.first?.attributes["custom"] == .string("added"))
    }

    @Test
    func keepsOnlyUnchangedSpansFromAMixedBatch() {
        let recorder = MockSpanExporter()
        let pipeline = SessionPolicyPipelineTestBuilder.buildExportChain(proxy: recorder) { span in
            guard span.name == "changed" else {
                return span
            }

            var span = span
            return span.settingAttributes(span.attributes.merging(["session.id": .string(Self.otherSessionId)]) { _, new in new })
        }
        let attributes: [String: AttributeValue] = ["session.id": .string(Self.sessionId)]

        _ = pipeline.export(
            spans: [
                SpanDataTestBuilder.build(name: "kept", attributes: attributes),
                SpanDataTestBuilder.build(name: "changed", attributes: attributes)
            ],
            explicitTimeout: nil
        )

        #expect(recorder.exportedSpans.map(\.name) == ["kept"])
    }

    /// A standalone processor has no sessions, so its interceptor may still rewrite the attribute.
    @Test
    func standaloneInterceptorMayChangeId() {
        let recorder = MockSpanExporter()
        let exporter = SpanInterceptorExporter(
            with: { span in
                var span = span
                return span.settingAttributes(span.attributes.merging(["session.id": .string(Self.otherSessionId)]) { _, new in new })
            },
            proxy: recorder
        )

        _ = exporter.export(
            spans: [SpanDataTestBuilder.build(attributes: ["session.id": .string(Self.sessionId)])],
            explicitTimeout: nil
        )

        #expect(recorder.exportedSpans.first?.attributes["session.id"] == .string(Self.otherSessionId))
    }


    // MARK: - Global attribute named session.id

    @Test
    func globalIdAttributeRemovedWithNoSession() {
        let span = SessionPolicyPipelineTestBuilder.startAndEndSpan(
            globalAttributes: ["session.id": .string(Self.sessionId)],
            runtimeSessionId: nil,
            ownsSessionId: true
        )

        #expect(span.attributes["session.id"] == nil)

        let recorder = MockSpanExporter()
        _ = SessionPolicyPipelineTestBuilder.buildExportChain(proxy: recorder, interceptor: nil).export(spans: [span], explicitTimeout: nil)

        #expect(recorder.exportedSpans.isEmpty)
    }

    @Test
    func runtimeSessionIdOverridesGlobalAttribute() {
        let span = SessionPolicyPipelineTestBuilder.startAndEndSpan(
            globalAttributes: ["session.id": .string(Self.otherSessionId)],
            runtimeSessionId: Self.sessionId,
            ownsSessionId: true
        )

        #expect(span.attributes["session.id"] == .string(Self.sessionId))
    }

    @Test
    func standaloneProcessorKeepsGlobalAttribute() {
        let span = SessionPolicyPipelineTestBuilder.startAndEndSpan(
            globalAttributes: ["session.id": .string(Self.sessionId)],
            runtimeSessionId: nil,
            ownsSessionId: false
        )

        #expect(span.attributes["session.id"] == .string(Self.sessionId))
    }


    // MARK: - Debug logging

    /// With debug logging on, a batch logs how many spans it dropped for a changed `session.id`.
    ///
    /// A span the interceptor itself drops is not counted, and a batch with no such drop logs nothing.
    @Test
    func logsChangedIdCountWhenDebugOn() {
        let recorder = MockSpanExporter()
        let logged = DroppedCountRecorder()
        let exporter = SpanInterceptorExporter(
            with: Self.changeOrDropByName,
            proxy: recorder,
            requiresUnchangedSessionId: true,
            debugEnabled: true,
            logDroppedCount: logged.record
        )
        let attributes: [String: AttributeValue] = ["session.id": .string(Self.sessionId)]

        _ = exporter.export(
            spans: [
                SpanDataTestBuilder.build(name: "kept", attributes: attributes),
                SpanDataTestBuilder.build(name: "changed", attributes: attributes),
                SpanDataTestBuilder.build(name: "dropped", attributes: attributes)
            ],
            explicitTimeout: nil
        )
        _ = exporter.export(spans: [SpanDataTestBuilder.build(name: "kept", attributes: attributes)], explicitTimeout: nil)

        #expect(logged.counts == [1])
        #expect(recorder.exportedSpans.map(\.name) == ["kept", "kept"])
    }

    @Test
    func logsNothingForChangedIdWhenDebugOff() {
        let logged = DroppedCountRecorder()
        let exporter = SpanInterceptorExporter(
            with: Self.changeOrDropByName,
            proxy: MockSpanExporter(),
            requiresUnchangedSessionId: true,
            debugEnabled: false,
            logDroppedCount: logged.record
        )

        _ = exporter.export(
            spans: [SpanDataTestBuilder.build(name: "changed", attributes: ["session.id": .string(Self.sessionId)])],
            explicitTimeout: nil
        )

        #expect(logged.counts.isEmpty)
    }


    // MARK: - Helpers

    /// Replaces the session ID of a span named "changed", drops one named "dropped", and keeps the rest.
    private static func changeOrDropByName(_ span: SpanData) -> SpanData? {
        switch span.name {
        case "changed":
            var span = span
            return span.settingAttributes(span.attributes.merging(["session.id": .string(otherSessionId)]) { _, new in new })

        case "dropped":
            return nil

        default:
            return span
        }
    }
}
