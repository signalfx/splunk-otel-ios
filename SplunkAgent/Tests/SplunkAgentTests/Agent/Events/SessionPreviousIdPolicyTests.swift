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

/// `session.previous_id` is agent-only on every span, like `session.id`: a global attribute with that name
/// is removed, and a span is dropped if the customer span interceptor adds, changes or removes it.
@Suite
struct SessionPreviousIdPolicyTests {
    private static let sessionId = "0123456789abcdef0123456789abcdef"
    private static let otherSessionId = "fedcba9876543210fedcba9876543210"

    /// A span of the second session of a pair: the agent's ID and the ID of the session before.
    private static let sessionAttributes: [String: AttributeValue] = [
        "session.id": .string(sessionId),
        "session.previous_id": .string(otherSessionId)
    ]


    // MARK: - Interceptor

    @Test
    func dropsSpanWhenInterceptorReplacesPreviousId() {
        let recorder = MockSpanExporter()
        let pipeline = SessionPolicyPipelineTestBuilder.buildExportChain(proxy: recorder) { span in
            var span = span
            return span.settingAttributes(
                span.attributes.merging(["session.previous_id": .string(Self.sessionId)]) { _, new in new }
            )
        }

        let span = SpanDataTestBuilder.build(attributes: Self.sessionAttributes)
        _ = pipeline.export(spans: [span], explicitTimeout: nil)

        #expect(recorder.exportedSpans.isEmpty)
    }

    @Test
    func dropsSpanWhenInterceptorAddsPreviousId() {
        let recorder = MockSpanExporter()
        let pipeline = SessionPolicyPipelineTestBuilder.buildExportChain(proxy: recorder) { span in
            var span = span
            return span.settingAttributes(
                span.attributes.merging(["session.previous_id": .string(Self.otherSessionId)]) { _, new in new }
            )
        }

        let span = SpanDataTestBuilder.build(attributes: ["session.id": .string(Self.sessionId)])
        _ = pipeline.export(spans: [span], explicitTimeout: nil)

        #expect(recorder.exportedSpans.isEmpty)
    }

    @Test
    func dropsSpanWhenInterceptorRemovesPreviousId() {
        let recorder = MockSpanExporter()
        let pipeline = SessionPolicyPipelineTestBuilder.buildExportChain(proxy: recorder) { span in
            var attributes = span.attributes
            attributes["session.previous_id"] = nil
            var span = span
            return span.settingAttributes(attributes)
        }

        let span = SpanDataTestBuilder.build(attributes: Self.sessionAttributes)
        _ = pipeline.export(spans: [span], explicitTimeout: nil)

        #expect(recorder.exportedSpans.isEmpty)
    }

    @Test
    func keepsSpanWhenInterceptorLeavesPreviousId() {
        let recorder = MockSpanExporter()
        let pipeline = SessionPolicyPipelineTestBuilder.buildExportChain(proxy: recorder) { span in
            var span = span
            return span.settingAttributes(span.attributes.merging(["custom": .string("added")]) { _, new in new })
        }

        let span = SpanDataTestBuilder.build(attributes: Self.sessionAttributes)
        _ = pipeline.export(spans: [span], explicitTimeout: nil)

        #expect(recorder.exportedSpans.count == 1)
        #expect(recorder.exportedSpans.first?.attributes["session.previous_id"] == .string(Self.otherSessionId))
    }

    /// A standalone processor has no sessions, so its interceptor may still rewrite the attribute.
    @Test
    func standaloneInterceptorMayChangePreviousId() {
        let recorder = MockSpanExporter()
        let exporter = SpanInterceptorExporter(
            with: { span in
                var span = span
                return span.settingAttributes(
                    span.attributes.merging(["session.previous_id": .string(Self.sessionId)]) { _, new in new }
                )
            },
            proxy: recorder
        )

        let span = SpanDataTestBuilder.build(attributes: Self.sessionAttributes)
        _ = exporter.export(spans: [span], explicitTimeout: nil)

        #expect(recorder.exportedSpans.first?.attributes["session.previous_id"] == .string(Self.sessionId))
    }


    // MARK: - Global attribute named session.previous_id

    @Test
    func globalPreviousIdIsRemoved() {
        let span = SessionPolicyPipelineTestBuilder.startAndEndSpan(
            globalAttributes: ["session.previous_id": .string(Self.otherSessionId)],
            runtimeSessionId: Self.sessionId,
            ownsSessionId: true
        )

        #expect(span.attributes["session.previous_id"] == nil)
        #expect(span.attributes["session.id"] == .string(Self.sessionId))
    }

    @Test
    func globalPreviousIdRemovedWithNoSession() {
        let span = SessionPolicyPipelineTestBuilder.startAndEndSpan(
            globalAttributes: ["session.previous_id": .string(Self.otherSessionId)],
            runtimeSessionId: nil,
            ownsSessionId: true
        )

        #expect(span.attributes["session.previous_id"] == nil)
    }

    /// A reserved global attribute does not take the slot that the agent's `session.id` needs on a span at its
    /// attribute limit.
    @Test
    func reservedGlobalLeavesRoomForAgentId() {
        let limit = SpanLimits().attributeCountLimit
        var globalAttributes = Dictionary(
            uniqueKeysWithValues: (0 ..< limit - 1).map { index in ("global.\(index)", AttributeValue.int(index)) }
        )
        globalAttributes["session.previous_id"] = .string(Self.otherSessionId)

        let span = SessionPolicyPipelineTestBuilder.startAndEndSpan(
            globalAttributes: globalAttributes,
            runtimeSessionId: Self.sessionId,
            ownsSessionId: true
        )

        #expect(span.attributes["session.id"] == .string(Self.sessionId))
        #expect(span.attributes["session.previous_id"] == nil)
    }

    /// A `session.previous_id` set on the span builder is removed when the agent has no such value.
    @Test
    func spanBuilderPreviousIdRemoved() {
        let span = SessionPolicyPipelineTestBuilder.startAndEndSpan(
            spanAttributes: ["session.previous_id": .string(Self.otherSessionId)],
            globalAttributes: [:],
            runtimeSessionId: Self.sessionId,
            ownsSessionId: true
        )

        #expect(span.attributes["session.id"] == .string(Self.sessionId))
        #expect(span.attributes["session.previous_id"] == nil)
    }

    @Test
    func standaloneKeepsGlobalPreviousId() {
        let span = SessionPolicyPipelineTestBuilder.startAndEndSpan(
            globalAttributes: ["session.previous_id": .string(Self.otherSessionId)],
            runtimeSessionId: nil,
            ownsSessionId: false
        )

        #expect(span.attributes["session.previous_id"] == .string(Self.otherSessionId))
    }
}
