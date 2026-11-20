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
    func bufferedSpanUsesNewEndpointWithoutPreflush() throws {
        let exporter = RecordingEndpointExporter()
        let fixture = makeFixture(exporter: exporter)
        let endpoint = try #require(URL(string: "https://example.com/v1/traces"))

        endSpan(named: "pre-endpoint-change")
        fixture.processor.setEndpoint(endpoint)

        #expect(exporter.events == [.setEndpoint(endpoint)])
        #expect(exporter.waitForExport(timeout: 1) == .success)

        #expect(
            exporter.events == [
                .setEndpoint(endpoint),
                .export(["pre-endpoint-change"], endpoint)
            ]
        )
    }

    @Test
    func bufferedSpanUsesPendingStorageAfterImmediateClear() throws {
        let initialEndpoint = try #require(URL(string: "https://example.com/v1/traces"))
        let exporter = RecordingEndpointExporter(endpoint: initialEndpoint)
        let fixture = makeFixture(exporter: exporter)

        endSpan(named: "pre-endpoint-clear")
        fixture.processor.clearEndpoint()

        #expect(exporter.events == [.clearEndpoint])
        #expect(exporter.waitForExport(timeout: 1) == .success)

        #expect(
            exporter.events == [
                .clearEndpoint,
                .export(["pre-endpoint-clear"], nil)
            ]
        )
    }

    @Test
    func emptyBufferChangesEndpointWithoutFlushingExporter() throws {
        let exporter = RecordingEndpointExporter()
        let fixture = makeFixture(exporter: exporter)
        let endpoint = try #require(URL(string: "https://example.com/v1/traces"))

        fixture.processor.setEndpoint(endpoint)
        #expect(exporter.events == [.setEndpoint(endpoint)])
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
        case export([String], URL?)
        case flush
        case setEndpoint(URL)
        case clearEndpoint
    }

    private let lock = NSLock()
    private let exportCompleted = DispatchSemaphore(value: 0)
    private var storedEvents: [Event] = []
    private var storedEndpoint: URL?

    init(endpoint: URL? = nil) {
        storedEndpoint = endpoint
    }

    var events: [Event] {
        withLock { storedEvents }
    }

    func export(spans: [SpanData], explicitTimeout _: TimeInterval?) -> SpanExporterResultCode {
        withLock {
            storedEvents.append(.export(spans.map(\.name), storedEndpoint))
        }
        exportCompleted.signal()
        return .success
    }

    func flush(explicitTimeout _: TimeInterval?) -> SpanExporterResultCode {
        withLock {
            storedEvents.append(.flush)
        }
        return .success
    }

    func shutdown(explicitTimeout _: TimeInterval?) {}

    func setEndpoint(_ newEndpoint: URL, headers _: [String: String]?) {
        withLock {
            storedEndpoint = newEndpoint
            storedEvents.append(.setEndpoint(newEndpoint))
        }
    }

    func clearEndpoint() {
        withLock {
            storedEndpoint = nil
            storedEvents.append(.clearEndpoint)
        }
    }

    func waitForExport(timeout: TimeInterval) -> DispatchTimeoutResult {
        exportCompleted.wait(timeout: .now() + timeout)
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
