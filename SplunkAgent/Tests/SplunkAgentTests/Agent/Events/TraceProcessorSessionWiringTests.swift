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

final class TraceProcessorSessionWiringTests: XCTestCase {

    // MARK: - Tests

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

        let interceptorRecorder = InterceptedSpanRecorder()
        let recorder = InterceptedSpanRecorder()
        let agentSpanReported = expectation(description: "the span with an agent session ID reaches didIntercept")
        recorder.onName("agent-session") {
            agentSpanReported.fulfill()
        }

        // Kept alive here: the attributes processor holds it unowned.
        let runtimeAttributes = EmptyRuntimeAttributes()
        let processor = OTLPTraceProcessor(
            with: nil,
            resources: WiringTestResources(),
            runtimeAttributes: runtimeAttributes,
            globalAttributes: { [:] },
            debugEnabled: false,
            spanInterceptor: { span in
                interceptorRecorder.record([span])

                return span
            },
            activityTracker: IgnoredActivityTracker(),
            enforcesSessionPolicy: true,
            didIntercept: { spans in
                recorder.record(spans)
            }
        )
        let tracer = processor.tracerProvider.get(instrumentationName: "wiring-test")

        endSpan(named: "bad-shape", sessionId: "no-op", tracer: tracer)
        endSpan(named: "no-session", sessionId: nil, tracer: tracer)
        endSpan(named: "agent-session", sessionId: "0123456789abcdef0123456789abcdef", tracer: tracer)
        _ = processor.forceFlushBufferedSpans(timeout: 10)

        // Positive control: the span ended last arrived, so the two spans before it were processed too.
        wait(for: [agentSpanReported], timeout: 10)
        _ = processor.forceFlushBufferedSpans(timeout: 10)

        XCTAssertEqual(interceptorRecorder.names, ["agent-session"])
        XCTAssertEqual(recorder.names, ["agent-session"])
    }


    // MARK: - Private methods

    private func endSpan(named name: String, sessionId: String?, tracer: any Tracer) {
        let builder = tracer.spanBuilder(spanName: name)

        if let sessionId {
            builder.setAttribute(key: "session.id", value: sessionId)
        }

        builder.startSpan().end()
    }
}


// MARK: - Test doubles

/// Records the names of the spans that reach the interceptor or `didIntercept`, from any export thread.
private final class InterceptedSpanRecorder {

    private let lock = NSLock()
    private var recordedNames: [String] = []
    private var watchedName: String?
    private var onWatchedName: (() -> Void)?

    var names: [String] {
        lock.lock()
        defer { lock.unlock() }

        return recordedNames
    }

    func onName(_ name: String, perform action: @escaping () -> Void) {
        lock.lock()
        defer { lock.unlock() }

        watchedName = name
        onWatchedName = action
    }

    func record(_ spans: [SpanData]) {
        lock.lock()
        recordedNames.append(contentsOf: spans.map(\.name))
        let action = spans.contains { $0.name == watchedName } ? onWatchedName : nil
        lock.unlock()

        action?()
    }
}

private final class EmptyRuntimeAttributes: RuntimeAttributes {
    let all: [String: Any] = [:]
}

private struct IgnoredActivityTracker: ActivityTracker {
    func trackActivity(at _: Date) {}
}

private struct WiringTestResources: AgentResources {
    let appName = "WiringTestApp"
    let appVersion = "1.0"
    let appBuild = "1"
    let appDeploymentEnvironment = "test"
    let agentHybridType: String? = nil
    let agentVersion = "test"
    let deviceModelIdentifier = "test-device"
    let deviceManufacturer = "Apple"
    let deviceID = "test-device-id"
    let osName = "iOS"
    let osVersion = "test-os"
    let osDescription = "test-os-description"
    let osType = "darwin"
}
