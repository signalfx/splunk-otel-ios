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

        // The span should be our testable mock span
        let mockSpan = try XCTUnwrap(span as? MockSpan)

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

        let mockSpan = try XCTUnwrap(span as? MockSpan)

        // Verify custom attributes are present
        XCTAssertEqual(mockSpan.attributes["job_id"]?.description, "job-5678")
        XCTAssertEqual(mockSpan.attributes["data_size_kb"]?.description, "1024")

        span.end()
    }
}

/// A minimal, final mock class to satisfy the AgentSharedState protocol.
///
/// Making it final resolves the Sendable warning.
private final class AgentSharedStateMock: AgentSharedState {
    let agentVersion: String = "1.2.3-test"
    let sessionId: String = "test-session-id"

    func applicationState(for _: Date) -> String? {
        "active"
    }
}
