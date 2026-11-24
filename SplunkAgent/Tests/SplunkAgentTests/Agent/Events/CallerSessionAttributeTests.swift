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
import XCTest

@testable import SplunkAgent
@testable import SplunkCustomTracking
@testable import SplunkOpenTelemetry

/// `session.id` and `session.previous_id` are agent-only on custom events, errors and workflow spans.
///
/// A value the app supplies is ignored, so the signal is exported under the session the agent
/// assigned, or dropped when it has none. The event and error tests run the agent's event path:
/// event -> log record -> span (with the session stamped at start). The workflow tests start from
/// the span `trackWorkflow` returns, which gets the session at start too. Both then export through
/// `SessionPolicySpanExporter` -> `SpanInterceptorExporter` with an interceptor that changes nothing.
final class CallerSessionAttributeTests: XCTestCase {
    private static let agentSessionId = "0123456789abcdef0123456789abcdef"
    private static let savedSessionId = "fedcba9876543210fedcba9876543210"


    // MARK: - Custom events and errors

    func testCustomEventCallerIdKeepsAgentSession() {
        let event = makeCustomEvent(sessionId: Self.agentSessionId, attributes: ["session.id": .string(Self.savedSessionId)])

        let exported = export(event, currentSessionId: Self.agentSessionId)

        XCTAssertEqual(exported.count, 1)
        XCTAssertEqual(exported.first?.attributes["session.id"], .string(Self.agentSessionId))
    }

    func testCustomErrorNonAgentCallerIdKept() {
        let event = makeCustomEvent(
            name: "error",
            component: "error",
            sessionId: Self.agentSessionId,
            attributes: ["session.id": .string("3F2504E0-4F89-11D3-9A0C-0305E82C3301")]
        )

        let exported = export(event, currentSessionId: Self.agentSessionId)

        XCTAssertEqual(exported.count, 1, "A custom error was dropped because of the caller's session.id")
        XCTAssertEqual(exported.first?.attributes["session.id"], .string(Self.agentSessionId))
    }

    func testCustomEventCallerPreviousIdCarriesNone() {
        let event = makeCustomEvent(
            sessionId: Self.agentSessionId,
            attributes: ["session.previous_id": .string(Self.savedSessionId), "plan": .string("pro")]
        )

        let exported = export(event, currentSessionId: Self.agentSessionId)

        XCTAssertEqual(exported.count, 1)
        XCTAssertNil(exported.first?.attributes["session.previous_id"])
        XCTAssertEqual(exported.first?.attributes["plan"], .string("pro"))
    }


    // MARK: - Workflow spans

    func testSessionlessWorkflowLateIdDropped() {
        let exported = exportWorkflowSpan(currentSessionId: nil) { span in
            span.setAttribute(key: "session.id", value: Self.savedSessionId)
        }

        XCTAssertTrue(exported.isEmpty, "A workflow span started with no session was exported under the caller's session.id")
    }

    func testWorkflowSpanIdReplacedKeepsAgentSession() {
        let exported = exportWorkflowSpan(currentSessionId: Self.agentSessionId) { span in
            span.setAttribute(key: "session.id", value: Self.savedSessionId)
        }

        XCTAssertEqual(exported.count, 1)
        XCTAssertEqual(exported.first?.attributes["session.id"], .string(Self.agentSessionId))
    }

    func testWorkflowSpanKeepsAgentSessionOverCaller() {
        let exported = exportWorkflowSpan(currentSessionId: Self.agentSessionId) { span in
            span.setAttribute(key: "session.id", value: nil)
            span.setAttributes([
                "session.previous_id": .string(Self.savedSessionId),
                "plan": .string("pro")
            ])
        }

        XCTAssertEqual(exported.count, 1)
        XCTAssertEqual(exported.first?.attributes["session.id"], .string(Self.agentSessionId))
        XCTAssertNil(exported.first?.attributes["session.previous_id"])
        XCTAssertEqual(exported.first?.attributes["plan"], .string("pro"))
    }


    // MARK: - Helpers

    private func makeCustomEvent(
        name: String = "purchase",
        component: String = "custom-event",
        sessionId: String?,
        attributes: [String: EventAttributeValue]
    ) -> CustomTrackingDataEvent {
        CustomTrackingDataEvent(
            metadata: CustomTrackingMetadata(),
            data: CustomTrackingData(name: name, component: component, attributes: attributes),
            sessionId: sessionId
        )
    }

    /// Emits the event as a log record, converts it as `OTLPLogToSpanExporter` does, and exports the span.
    private func export(_ event: any AgentEvent, currentSessionId: String?) -> [SpanData] {
        let logRecorder = LogRecordRecorder()
        LoggerProviderBuilder()
            .with(processors: [logRecorder])
            .build()
            .get(instrumentationScopeName: event.instrumentationScope)
            .logRecordBuilder()
            .build(with: event)
            .emit()

        let runtimeAttributes = MockRuntimeAttributes(sessionId: currentSessionId)
        let spanRecorder = EndedSpanRecorder()
        let tracerProvider = makeTracerProvider(runtimeAttributes: runtimeAttributes, spanRecorder: spanRecorder)

        // `OTLPAttributesSpanProcessor` holds the runtime attributes unowned.
        withExtendedLifetime(runtimeAttributes) {
            _ = OTLPLogToSpanExporter(agentVersion: "test", tracerProvider: tracerProvider)
                .export(logRecords: logRecorder.records, explicitTimeout: nil)
        }

        return exportThroughAgentPipeline(spanRecorder.spans)
    }

    /// Starts a workflow through `CustomTrackingInternal.track(_:)`, lets the caller change it, and
    /// exports it.
    private func exportWorkflowSpan(currentSessionId: String?, changeAfterStart: (any Span) -> Void) -> [SpanData] {
        let runtimeAttributes = MockRuntimeAttributes(sessionId: currentSessionId)
        let spanRecorder = EndedSpanRecorder()
        let tracerProvider = makeTracerProvider(runtimeAttributes: runtimeAttributes, spanRecorder: spanRecorder)

        // The module starts workflow spans with the global tracer provider.
        let originalTracerProvider = OpenTelemetry.instance.tracerProvider
        OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)
        defer { OpenTelemetry.registerTracerProvider(tracerProvider: originalTracerProvider) }

        withExtendedLifetime(runtimeAttributes) {
            let span = CustomTrackingInternal().track("checkout")
            changeAfterStart(span)
            span.end()
        }

        return exportThroughAgentPipeline(spanRecorder.spans)
    }

    private func makeTracerProvider(runtimeAttributes: MockRuntimeAttributes, spanRecorder: EndedSpanRecorder) -> TracerProviderSdk {
        TracerProviderBuilder()
            .add(
                spanProcessor: OTLPAttributesSpanProcessor(
                    with: runtimeAttributes,
                    activityTracker: MockActivityTracker(),
                    ownsSessionId: true
                )
            )
            .add(spanProcessor: spanRecorder)
            .build()
    }

    /// The agent's export order (`OTLPTraceProcessor`): the session policy, then a customer
    /// interceptor that changes nothing, with the unchanged-ID check.
    private func exportThroughAgentPipeline(_ spans: [SpanData]) -> [SpanData] {
        let exporter = MockSpanExporter()
        let pipeline = SessionPolicyPipelineTestBuilder.buildExportChain(proxy: exporter, interceptor: { $0 })
        _ = pipeline.export(spans: spans, explicitTimeout: nil)

        return exporter.exportedSpans
    }
}
