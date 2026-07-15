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

@Suite(.serialized)
struct OTLPTraceProcessorEndpointTests {

    // MARK: - Endpoint changes

    @Test
    func setEndpointFlushesBufferedSpansBeforeChangingEndpoint() throws {
        let exporter = RecordingEndpointExporter()
        let fixture = makeFixture(exporter: exporter)
        let endpoint = try #require(URL(string: "https://example.com/v1/traces"))

        endSpan(named: "pre-endpoint-change")
        fixture.processor.setEndpoint(endpoint)

        #expect(exporter.waitForEndpointChange(timeout: 1) == .success)

        #expect(
            exporter.events == [
                .export(["pre-endpoint-change"]),
                .flush,
                .setEndpoint(endpoint)
            ]
        )
    }

    @Test
    func clearEndpointFlushesBufferedSpansBeforeClearingEndpoint() {
        let exporter = RecordingEndpointExporter()
        let fixture = makeFixture(exporter: exporter)

        endSpan(named: "pre-endpoint-clear")
        fixture.processor.clearEndpoint()

        #expect(exporter.waitForEndpointChange(timeout: 1) == .success)

        #expect(
            exporter.events == [
                .export(["pre-endpoint-clear"]),
                .flush,
                .clearEndpoint
            ]
        )
    }

    @Test
    func setEndpointDoesNotBlockMainThreadWhileFlushIsPending() throws {
        let exporter = RecordingEndpointExporter(blockFlush: true)
        let fixture = makeFixture(exporter: exporter)
        let endpoint = try #require(URL(string: "https://example.com/v1/traces"))
        let callReturned = DispatchSemaphore(value: 0)

        endSpan(named: "pre-blocked-endpoint-change")
        DispatchQueue.main.async {
            fixture.processor.setEndpoint(endpoint)
            callReturned.signal()
        }

        #expect(callReturned.wait(timeout: .now() + 1) == .success)
        #expect(exporter.waitUntilFlushStarts(timeout: 1) == .success)
        #expect(!exporter.events.contains(.setEndpoint(endpoint)))

        exporter.resumeFlush()

        #expect(exporter.waitForEndpointChange(timeout: 1) == .success)
        #expect(
            exporter.events == [
                .export(["pre-blocked-endpoint-change"]),
                .flush,
                .setEndpoint(endpoint)
            ]
        )
    }
}


// MARK: - Helpers

extension OTLPTraceProcessorEndpointTests {

    private func makeFixture(exporter: RecordingEndpointExporter) -> TraceProcessorFixture {
        let runtimeAttributes = MockRuntimeAttributes(all: [:])
        let activityTracker = MockActivityTracker()
        let processor = OTLPTraceProcessor(
            backgroundTraceExporter: exporter,
            resources: MockAgentResources(),
            runtimeAttributes: runtimeAttributes,
            globalAttributes: { [:] },
            debugEnabled: false,
            spanInterceptor: nil,
            activityTracker: activityTracker
        )

        return TraceProcessorFixture(
            processor: processor,
            runtimeAttributes: runtimeAttributes,
            activityTracker: activityTracker
        )
    }

    private func endSpan(named name: String) {
        OpenTelemetry
            .instance
            .tracerProvider
            .get(instrumentationName: "endpoint-test", instrumentationVersion: "1.0")
            .spanBuilder(spanName: name)
            .startSpan()
            .end()
    }
}


private struct TraceProcessorFixture {
    let processor: OTLPTraceProcessor
    let runtimeAttributes: MockRuntimeAttributes
    let activityTracker: MockActivityTracker
}


private final class RecordingEndpointExporter: EndpointConfigurableSpanExporter {

    enum Event: Equatable {
        case export([String])
        case flush
        case setEndpoint(URL)
        case clearEndpoint
    }

    private let lock = NSLock()
    private let blockFlush: Bool
    private let endpointChanged = DispatchSemaphore(value: 0)
    private let flushStarted = DispatchSemaphore(value: 0)
    private let flushResume = DispatchSemaphore(value: 0)
    private var storedEvents: [Event] = []

    init(blockFlush: Bool = false) {
        self.blockFlush = blockFlush
    }

    var events: [Event] {
        withLock { storedEvents }
    }

    func export(spans: [SpanData], explicitTimeout _: TimeInterval?) -> SpanExporterResultCode {
        withLock {
            storedEvents.append(.export(spans.map(\.name)))
        }
        return .success
    }

    func flush(explicitTimeout _: TimeInterval?) -> SpanExporterResultCode {
        withLock {
            storedEvents.append(.flush)
        }
        flushStarted.signal()
        if blockFlush {
            flushResume.wait()
        }
        return .success
    }

    func shutdown(explicitTimeout _: TimeInterval?) {}

    func setEndpoint(_ newEndpoint: URL, headers _: [String: String]?) {
        withLock {
            storedEvents.append(.setEndpoint(newEndpoint))
        }
        endpointChanged.signal()
    }

    func clearEndpoint() {
        withLock {
            storedEvents.append(.clearEndpoint)
        }
        endpointChanged.signal()
    }

    func waitForEndpointChange(timeout: TimeInterval) -> DispatchTimeoutResult {
        endpointChanged.wait(timeout: .now() + timeout)
    }

    func waitUntilFlushStarts(timeout: TimeInterval) -> DispatchTimeoutResult {
        flushStarted.wait(timeout: .now() + timeout)
    }

    func resumeFlush() {
        flushResume.signal()
    }

    private func withLock<T>(_ work: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try work()
    }
}


private struct MockAgentResources: AgentResources {
    let appName = "EndpointTestApp"
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
