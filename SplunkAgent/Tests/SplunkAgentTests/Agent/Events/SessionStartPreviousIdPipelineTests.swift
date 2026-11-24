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
@testable import SplunkOpenTelemetry

/// A `session.start` span keeps its `session.previous_id` through the agent's trace pipeline.
///
/// The attributes processor removes `session.previous_id` from every span at start. The log-to-span
/// exporter sets the attributes of the log record after the span starts, so the value of the event
/// survives. This test fails if that order ever changes.
final class SessionStartPreviousIdPipelineTests: XCTestCase {

    // MARK: - Static constants

    private static let previousSessionId = "fedcba9876543210fedcba9876543210"


    // MARK: - Tests

    func testSessionStartKeepsPreviousId() throws {
        let originalTracerProvider = OpenTelemetry.instance.tracerProvider
        addTeardownBlock {
            OpenTelemetry.registerTracerProvider(tracerProvider: originalTracerProvider)
        }

        let agent = try AgentTestBuilder.build(with: ConfigurationTestBuilder.buildDefault())
        let sessionId = agent.currentSession.currentSessionId

        let exporter = RecordingTraceExporter()
        let traceProcessor = OTLPTraceProcessor(
            backgroundTraceExporter: exporter,
            resources: MockAgentResources(),
            runtimeAttributes: agent.runtimeAttributes,
            globalAttributes: { [:] },
            debugEnabled: false,
            spanInterceptor: { $0 },
            activityTracker: agent.currentSession,
            enforcesSessionPolicy: true
        )
        let event = SessionStartEvent(timestamp: Date(), sessionId: sessionId, previousSessionId: Self.previousSessionId, screenName: nil)

        emit(event, on: traceProcessor)
        flush(traceProcessor)

        let spans = exporter.spans.filter { $0.name == "session.start" }
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans.first?.attributes["session.id"], .string(sessionId))
        XCTAssertEqual(spans.first?.attributes["session.previous_id"], .string(Self.previousSessionId))
    }

    /// A held start that a span of its session releases, through the agent's `didIntercept` closure,
    /// keeps its own `session.id`, `session.previous_id` and `screen.name` on the exported span.
    func testReleasedStartKeepsItsAttributes() throws {
        let originalTracerProvider = OpenTelemetry.instance.tracerProvider
        addTeardownBlock {
            OpenTelemetry.registerTracerProvider(tracerProvider: originalTracerProvider)
        }

        let configuration = try ConfigurationTestBuilder.buildDefault()
        let session = DefaultSession(
            sessionsModel: SessionsModel(storage: UserDefaultsStorageTestBuilder.buildCleanStorage(named: UUID().uuidString))
        )
        let agent = try AgentTestBuilder.build(with: configuration, session: session)
        let eventManager = try MockEventManager(with: configuration, agent: agent)
        agent.eventManager = eventManager
        let firstSessionId = session.currentSessionId

        // The linked session starts on one screen; its first telemetry comes from another.
        agent.runtimeAttributes.updateScreenName("StartScreen")
        session.rotateSession(previousSessionId: firstSessionId)
        let rotatedSessionId = session.currentSessionId
        agent.runtimeAttributes.updateScreenName("LaterScreen")

        // The pipeline `DefaultEventManager` builds, with a recorder in place of the background exporter.
        let exporter = RecordingTraceExporter()
        let traceProcessor = makeAgentTraceProcessor(exporter: exporter, runtimeAttributes: agent.runtimeAttributes, session: session)

        // The released start is converted to a span off the session's queue, as the agent does.
        let emitted = expectation(description: "released session.start converted to a span")
        eventManager.sentEventHandler = { event in
            guard event.name == "session.start", event.sessionId == rotatedSessionId else {
                return
            }

            DispatchQueue.global(qos: .utility)
                .async {
                    self.emit(event, on: traceProcessor)
                    emitted.fulfill()
                }
        }

        let tracer = traceProcessor.tracerProvider.get(instrumentationName: "session-start-previous-id-pipeline-tests")
        tracer.spanBuilder(spanName: "first-telemetry").startSpan().end()
        flush(traceProcessor)

        wait(for: [emitted], timeout: 10)
        flush(traceProcessor)

        let starts = exporter.spans.filter { $0.name == "session.start" }
        XCTAssertEqual(starts.count, 1)
        XCTAssertEqual(starts.first?.attributes["session.id"], .string(rotatedSessionId))
        XCTAssertEqual(starts.first?.attributes["session.previous_id"], .string(firstSessionId))
        XCTAssertEqual(starts.first?.attributes["screen.name"], .string("StartScreen"))
    }


    // MARK: - Helpers

    /// Makes the trace processor that `DefaultEventManager` builds, whose `didIntercept` closure releases held starts.
    private func makeAgentTraceProcessor(
        exporter: RecordingTraceExporter,
        runtimeAttributes: RuntimeAttributes,
        session: DefaultSession
    ) -> OTLPTraceProcessor {
        OTLPTraceProcessor(
            backgroundTraceExporter: exporter,
            resources: MockAgentResources(),
            runtimeAttributes: runtimeAttributes,
            globalAttributes: { [:] },
            debugEnabled: false,
            spanInterceptor: nil,
            activityTracker: session,
            enforcesSessionPolicy: true,
            didIntercept: { [weak session] spans in
                guard let session else {
                    return
                }

                var reportedSessionIds = Set<String>()

                for span in spans {
                    if case let .string(sessionId) = span.attributes["session.id"],
                        reportedSessionIds.insert(sessionId).inserted
                    {
                        session.trackAcceptedTelemetry(forSessionId: sessionId)
                    }
                }
            }
        )
    }

    /// Converts the event to a span as the agent does, on the tracer provider of the trace processor.
    private func emit(_ event: any AgentEvent, on traceProcessor: OTLPTraceProcessor) {
        let recorder = LogRecordRecorder()
        let loggerProvider = LoggerProviderBuilder()
            .with(processors: [recorder])
            .build()

        loggerProvider.get(instrumentationScopeName: event.instrumentationScope)
            .logRecordBuilder()
            .build(with: event)
            .emit()

        _ = OTLPLogToSpanExporter(agentVersion: "test", tracerProvider: traceProcessor.tracerProvider)
            .export(logRecords: recorder.records, explicitTimeout: nil)
    }

    /// Drains the in-memory batch through the export chain into the recording exporter.
    ///
    /// Off the main thread the flush returns only after the batch has passed the export chain.
    private func flush(_ traceProcessor: OTLPTraceProcessor) {
        let drained = expectation(description: "Buffered spans drained")

        DispatchQueue.global(qos: .utility)
            .async {
                if traceProcessor.forceFlushBufferedSpans(timeout: 5) == .success {
                    drained.fulfill()
                }
            }

        wait(for: [drained], timeout: 10)
    }
}
