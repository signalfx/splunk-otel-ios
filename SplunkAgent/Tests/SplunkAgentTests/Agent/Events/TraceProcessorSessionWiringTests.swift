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

import OpenTelemetryApi
import OpenTelemetrySdk
import SplunkCommon
import XCTest

@testable import SplunkAgent
@testable import SplunkOpenTelemetry

/// The session rules of the production span pipeline, on the wiring `DefaultEventManager` builds:
/// `enforcesSessionPolicy`, `ownsSessionId`, the processor order and the order of the session
/// policy and the customer interceptor.
final class TraceProcessorSessionWiringTests: XCTestCase {

    // MARK: - Static constants

    private static let agentSessionId = "00112233445566778899aabbccddeeff"
    private static let globalSessionId = "0123456789abcdef0123456789abcdef"
    private static let interceptorSessionId = "fedcba9876543210fedcba9876543210"


    // MARK: - Tests

    func testSessionlessSpanDroppedBeforeInterceptor() {
        let fixture = makeFixture()

        // The agent has no session, and a global attribute supplies a `session.id` of the right shape.
        emitSpan(named: "sessionless", in: fixture)
        flush(fixture)

        XCTAssertEqual(exportedNames(in: fixture), [])
        XCTAssertEqual(interceptedNames(in: fixture), [])
    }

    func testSpanExportsAgentSessionIdNotGlobal() {
        let fixture = makeFixture()

        emitSpan(named: "sessionless", in: fixture)
        fixture.runtimeAttributes.sessionId = Self.agentSessionId
        emitSpan(named: "kept", in: fixture)
        emitSpan(named: "changed", in: fixture)
        flush(fixture)

        // "kept" carries the agent's ID, not the global attribute's.
        XCTAssertEqual(exportedNames(in: fixture), ["kept"])
        XCTAssertEqual(fixture.exporter.spans.first { $0.name == "kept" }?.attributes["session.id"], .string(Self.agentSessionId))

        // The interceptor saw only spans that passed the policy; the one that changed the ID was dropped.
        XCTAssertEqual(interceptedNames(in: fixture), ["kept", "changed"])
    }

    func testEventManagerTraceProcessorPolicy() throws {
        // Building the event manager registers its tracer and logger providers globally.
        restoreOpenTelemetryGlobalsAtTeardown()

        let configuration = try ConfigurationTestBuilder.buildDefault()
        let agent = try AgentTestBuilder.build(with: configuration)
        let eventManager = try DefaultEventManager(with: configuration, agent: agent)
        agent.eventManager = eventManager
        stopAtTeardown(agent)

        XCTAssertTrue(eventManager.concreteTraceProcessor.enforcesSessionPolicy)
    }

    /// Spans without an agent session ID reach neither the customer `spanInterceptor` nor `didIntercept`.
    func testSpansWithoutAgentSessionIdSkipDidIntercept() {
        // Building the processor registers its tracer provider globally.
        restoreOpenTelemetryGlobalsAtTeardown()

        let interceptorRecorder = SpanNameRecorder()
        let recorder = SpanNameRecorder()
        let agentSpanReported = expectation(description: "the span with an agent session ID reaches didIntercept")
        recorder.onName("agent-session") {
            agentSpanReported.fulfill()
        }

        // Kept alive here: the attributes processor holds it unowned.
        let runtimeAttributes = MockRuntimeAttributes()
        let processor = OTLPTraceProcessor(
            with: nil,
            resources: MockAgentResources(),
            runtimeAttributes: runtimeAttributes,
            globalAttributes: { [:] },
            debugEnabled: false,
            spanInterceptor: { span in
                interceptorRecorder.record([span])

                return span
            },
            activityTracker: MockActivityTracker(),
            enforcesSessionPolicy: true,
            didIntercept: { spans in
                recorder.record(spans)
            }
        )
        let tracer = processor.tracerProvider.get(instrumentationName: "wiring-test")

        // The session ID comes from the runtime attributes, as in the agent: under the session policy the
        // attributes processor removes a `session.id` that the span itself sets.
        endSpan(named: "bad-shape", sessionId: "no-op", runtimeAttributes: runtimeAttributes, tracer: tracer)
        endSpan(named: "no-session", sessionId: nil, runtimeAttributes: runtimeAttributes, tracer: tracer)
        endSpan(named: "agent-session", sessionId: "0123456789abcdef0123456789abcdef", runtimeAttributes: runtimeAttributes, tracer: tracer)
        _ = processor.forceFlushBufferedSpans(timeout: 10)

        // Positive control: the span ended last arrived, so the two spans before it were processed too.
        wait(for: [agentSpanReported], timeout: 10)
        _ = processor.forceFlushBufferedSpans(timeout: 10)

        XCTAssertEqual(interceptorRecorder.names, ["agent-session"])
        XCTAssertEqual(recorder.names, ["agent-session"])
    }


    // MARK: - Fixture

    private func makeFixture() -> Fixture {
        let originalTracerProvider = OpenTelemetry.instance.tracerProvider

        // The agent's runtime attributes carry `session.id` while the agent has a session; it starts with none.
        let runtimeAttributes = MockRuntimeAttributes()

        // The interceptor records each span it sees. It sets another valid ID on "changed".
        let interceptedNames = SpanNameRecorder()
        let interceptor: SplunkSpanInterceptor = { span in
            interceptedNames.record([span])

            guard span.name == "changed" else {
                return span
            }

            var changed = span
            return changed.settingAttributes(span.attributes.merging(["session.id": .string(Self.interceptorSessionId)]) { $1 })
        }

        // The wiring `createProcessors` uses, with a recorder in place of the background exporter.
        let exporter = RecordingTraceExporter()
        let traceProcessor = OTLPTraceProcessor(
            backgroundTraceExporter: exporter,
            resources: MockAgentResources(),
            runtimeAttributes: runtimeAttributes,
            globalAttributes: { ["session.id": .string(Self.globalSessionId)] },
            debugEnabled: false,
            spanInterceptor: interceptor,
            activityTracker: MockActivityTracker(),
            enforcesSessionPolicy: true
        )

        addTeardownBlock {
            OpenTelemetry.registerTracerProvider(tracerProvider: originalTracerProvider)
        }

        return Fixture(
            runtimeAttributes: runtimeAttributes,
            traceProcessor: traceProcessor,
            exporter: exporter,
            interceptedNames: interceptedNames
        )
    }


    // MARK: - Spans

    /// The names this test emits.
    ///
    /// The pipeline is the global tracer provider while the test runs, so
    /// spans from instrumentation left over from other tests can reach it and are ignored here.
    private static let emittedNames: Set = ["sessionless", "kept", "changed"]

    private func exportedNames(in fixture: Fixture) -> [String] {
        fixture.exporter.spans.map(\.name).filter(Self.emittedNames.contains)
    }

    private func interceptedNames(in fixture: Fixture) -> [String] {
        fixture.interceptedNames.names.filter(Self.emittedNames.contains)
    }

    private func emitSpan(named name: String, in fixture: Fixture) {
        let tracer = fixture.traceProcessor.tracerProvider.get(instrumentationName: "trace-processor-session-wiring-tests")
        let span = tracer.spanBuilder(spanName: name).startSpan()
        span.end()
    }

    private func endSpan(
        named name: String,
        sessionId: String?,
        runtimeAttributes: MockRuntimeAttributes,
        tracer: any Tracer
    ) {
        runtimeAttributes.sessionId = sessionId
        tracer.spanBuilder(spanName: name).startSpan().end()
    }

    /// Drains the in-memory batch through the export chain into the recording exporter.
    private func flush(_ fixture: Fixture) {
        let drained = expectation(description: "Buffered spans drained")
        let traceProcessor = fixture.traceProcessor

        // Off the main thread the flush returns only after the batch has passed the export chain.
        DispatchQueue.global(qos: .utility)
            .async {
                if traceProcessor.forceFlushBufferedSpans(timeout: 5) == .success {
                    drained.fulfill()
                }
            }

        wait(for: [drained], timeout: 10)
    }
}


// MARK: - Test Support

private struct Fixture {
    // Retained because the attributes processor holds the runtime attributes unowned.
    let runtimeAttributes: MockRuntimeAttributes
    let traceProcessor: OTLPTraceProcessor
    let exporter: RecordingTraceExporter
    let interceptedNames: SpanNameRecorder
}
