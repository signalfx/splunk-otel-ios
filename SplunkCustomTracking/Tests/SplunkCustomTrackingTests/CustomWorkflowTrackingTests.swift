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

import OpenTelemetryApi
import OpenTelemetrySdk
import XCTest

@testable import SplunkCommon
@testable import SplunkCustomTracking

final class CustomWorkflowTrackingTests: XCTestCase {
    private var module: CustomTrackingInternal?
    private var mockSharedState: AgentSharedStateMock?
    private var originalTracerProvider: TracerProvider?

    override func setUp() {
        super.setUp()

        // Save the original provider
        originalTracerProvider = OpenTelemetry.instance.tracerProvider
        // Use the official, public API to register our test provider
        OpenTelemetry.registerTracerProvider(tracerProvider: MockTracerProvider())

        module = CustomTrackingInternal()
        // Create the mock and hold a strong reference to it
        mockSharedState = AgentSharedStateMock()
        // Assign the mock to the module's unowned property
        module?.sharedState = mockSharedState
    }

    override func tearDown() {
        if let originalTracerProvider {
            // Restore the original provider to ensure test isolation
            OpenTelemetry.registerTracerProvider(tracerProvider: originalTracerProvider)
        }

        module = nil
        mockSharedState = nil
        originalTracerProvider = nil

        super.tearDown()
    }

    func testTrackWorkflow_createsValidSpan() throws {
        let workflowName = "testValidWorkflow"

        let module = try XCTUnwrap(module)
        let span = module.track(workflowName)

        // The span should wrap our testable mock span
        let mockSpan = try startedSpan(of: span)

        // Verify span properties
        XCTAssertEqual(mockSpan.name, workflowName)
        XCTAssertTrue(mockSpan.isRecording)

        // Verify the default workflow attribute is set
        let workflowNameAttribute = mockSpan.attributes["workflow.name"]
        XCTAssertEqual(workflowNameAttribute?.description, workflowName)
        let componentAttribute = mockSpan.attributes["component"]
        XCTAssertEqual(componentAttribute?.description, "custom-workflow")

        // End the span and verify its state
        span.end()
        XCTAssertFalse(mockSpan.isRecording)
        XCTAssertNotNil(mockSpan.endTime)
    }

    func testTrackWorkflow_canAddCustomAttributes() throws {
        let module = try XCTUnwrap(module)

        let workflowName = "testAddCustomWorkflow"
        let span = module.track(workflowName)

        // Set custom attributes on the span, as a user would
        span.setAttribute(key: "job_id", value: .string("job-5678"))
        span.setAttribute(key: "data_size_kb", value: .int(1_024))

        let mockSpan = try startedSpan(of: span)

        // Verify custom attributes are present
        XCTAssertEqual(mockSpan.attributes["job_id"]?.description, "job-5678")
        XCTAssertEqual(mockSpan.attributes["data_size_kb"]?.description, "1024")

        span.end()
    }

    /// The agent stamps `session.id` when the span starts, so the app cannot change it afterwards.
    func testTrackWorkflowIgnoresSessionAttributes() throws {
        let module = try XCTUnwrap(module)

        let span = module.track("testSessionWorkflow")
        let mockSpan = try startedSpan(of: span)
        mockSpan.attributes["session.id"] = .string("agent-session")

        span.setAttribute(key: "session.id", value: .string("app-session"))
        span.setAttribute(key: "session.previous_id", value: "app-previous-session")
        span.setAttributes([
            "session.id": .string("app-session"),
            "session.previous_id": .string("app-previous-session"),
            "job_id": .string("job-5678")
        ])

        XCTAssertEqual(mockSpan.attributes["session.id"], .string("agent-session"))
        XCTAssertNil(mockSpan.attributes["session.previous_id"])
        XCTAssertEqual(mockSpan.attributes["job_id"], .string("job-5678"))

        span.end()
    }

    /// Ending the workflow span removes the span the app made active.
    ///
    /// The context manager matches spans by identity, so the workflow span must remove itself.
    func testTrackWorkflowEndRemovesActiveSpan() throws {
        let module = try XCTUnwrap(module)
        let contextProvider = OpenTelemetry.instance.contextProvider

        let span = module.track("testActiveWorkflow")
        contextProvider.setActiveSpan(span)
        defer { contextProvider.removeContextForSpan(span) }
        XCTAssertTrue(contextProvider.activeSpan === span)

        span.end()

        XCTAssertFalse(contextProvider.activeSpan === span)
    }

    /// The workflow leaves the active context before its span ends, so the `onEnd` processors do not see
    /// the ended workflow as the active span, for either `end` method.
    func testTrackWorkflowLeavesContextBeforeOnEnd() {
        let recorder = ActiveSpanAtEndRecorder()
        let tracer = TracerProviderBuilder()
            .add(spanProcessor: recorder)
            .build()
            .get(instrumentationName: "workflow-end-order-tests")
        let contextProvider = OpenTelemetry.instance.contextProvider

        let ended = CustomWorkflowSpan(span: tracer.spanBuilder(spanName: "ended").startSpan())
        contextProvider.setActiveSpan(ended)
        defer { contextProvider.removeContextForSpan(ended) }
        ended.end()

        let endedAtTime = CustomWorkflowSpan(span: tracer.spanBuilder(spanName: "endedAtTime").startSpan())
        contextProvider.setActiveSpan(endedAtTime)
        defer { contextProvider.removeContextForSpan(endedAtTime) }
        endedAtTime.end(time: Date())

        let activeSpansAtEnd = recorder.activeSpansAtEnd
        guard activeSpansAtEnd.count == 2 else {
            XCTFail("Expected one onEnd call per workflow, got \(activeSpansAtEnd.count)")
            return
        }

        XCTAssertFalse(activeSpansAtEnd[0] === ended)
        XCTAssertFalse(activeSpansAtEnd[1] === endedAtTime)
    }

    /// The wrapper passes the end time, status, name, one event and an exception to the real span.
    func testTrackWorkflowForwardsSpanCalls() throws {
        let module = try XCTUnwrap(module)
        let span = module.track("testForwardingWorkflow")
        let mockSpan = try startedSpan(of: span)
        let endTime = Date(timeIntervalSince1970: 1_800_000_000)

        span.name = "renamedWorkflow"
        span.status = .error(description: "failed")
        span.addEvent(name: "checkpoint")
        span.recordException(ForwardedTestError())
        span.end(time: endTime)

        XCTAssertEqual(mockSpan.name, "renamedWorkflow")
        XCTAssertEqual(mockSpan.status, .error(description: "failed"))
        XCTAssertEqual(mockSpan.recordedEventNames, ["checkpoint"])
        XCTAssertEqual(mockSpan.recordedExceptions.count, 1)
        XCTAssertEqual(mockSpan.endTime, endTime)
        XCTAssertFalse(mockSpan.isRecording)
    }

    /// The returned span wraps the tracer's span, so casting it to `ReadableSpan` returns `nil`.
    func testTrackWorkflowSpanIsNotAReadableSpan() throws {
        let module = try XCTUnwrap(module)
        let span = module.track("testReadableWorkflow")

        XCTAssertNil(span as? ReadableSpan)

        span.end()
    }


    // MARK: - Helpers

    /// The span the tracer started, which the returned workflow span wraps.
    private func startedSpan(of span: Span) throws -> MockSpan {
        let workflowSpan = try XCTUnwrap(span as? CustomWorkflowSpan)

        return try XCTUnwrap(workflowSpan.span as? MockSpan)
    }
}

/// A minimal, final mock class to satisfy the AgentSharedState protocol.
///
/// Making it final resolves the Sendable warning.
private final class AgentSharedStateMock: AgentSharedState {
    let agentVersion: String = "1.2.3-test"
    let sessionId: String = "test-session-id"
    let sessionMetadata: String? = nil

    func applicationState(for _: Date) -> String? {
        "active"
    }
}
