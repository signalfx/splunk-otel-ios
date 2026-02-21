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
import Testing

@testable import SplunkOpenTelemetryBackgroundExporter

@Suite
struct OTLPAdapterGroupingTests {

    // MARK: - Helpers

    private func makeSpanData(scopeName: String, scopeVersion: String) -> SpanData {
        let exporter = NoOpSpanExporter()
        let processor = SimpleSpanProcessor(spanExporter: exporter)
        let tracerProvider = TracerProviderBuilder()
            .add(spanProcessor: processor)
            .build()

        let tracer = tracerProvider.get(
            instrumentationName: scopeName,
            instrumentationVersion: scopeVersion
        )
        let span = tracer.spanBuilder(spanName: "test-span-\(scopeName)").startSpan()
        span.end()

        guard let readableSpan = span as? ReadableSpan else {
            fatalError("Could not get SpanData from span")
        }

        return readableSpan.toSpanData()
    }

    private func makeLogRecord(scopeName: String, scopeVersion: String, resource: Resource) -> ReadableLogRecord {
        let scope = InstrumentationScopeInfo(name: scopeName, version: scopeVersion)
        return ReadableLogRecord(
            resource: resource,
            instrumentationScopeInfo: scope,
            timestamp: Date(),
            observedTimestamp: nil,
            spanContext: nil,
            severity: nil,
            body: nil,
            attributes: [:]
        )
    }


    // MARK: - Tests

    @Test
    func spanAdapterGroupsByResourceAndScope() {
        // Both spans are created from the same tracer provider, so they share the same resource.
        let spanA = makeSpanData(scopeName: "scope-a", scopeVersion: "1.0.0")
        let spanB = makeSpanData(scopeName: "scope-b", scopeVersion: "2.0.0")

        let resourceSpans = SpanDataAdapter.toResourceSpans([spanA, spanB])

        #expect(resourceSpans.count == 1)
        #expect(resourceSpans.first?.scopeSpans.count == 2)
        let scopeNames = resourceSpans.first?.scopeSpans.compactMap { $0.scope?.name } ?? []
        #expect(Set(scopeNames) == Set(["scope-a", "scope-b"]))
    }

    @Test
    func spanAdapterGroupsSameScopeTogether() {
        // Both spans use the same instrumentation scope and should be grouped together.
        let spanA = makeSpanData(scopeName: "scope-a", scopeVersion: "1.0.0")
        let spanB = makeSpanData(scopeName: "scope-a", scopeVersion: "1.0.0")

        let resourceSpans = SpanDataAdapter.toResourceSpans([spanA, spanB])

        #expect(resourceSpans.count == 1)
        #expect(resourceSpans.first?.scopeSpans.count == 1)
        #expect(resourceSpans.first?.scopeSpans.first?.spans.count == 2)
        #expect(resourceSpans.first?.scopeSpans.first?.scope?.name == "scope-a")
    }

    @Test
    func logAdapterGroupsByResourceAndScope() {
        let resource = Resource(attributes: ["service.name": .string("test")])
        let logA = makeLogRecord(scopeName: "scope-a", scopeVersion: "1.0.0", resource: resource)
        let logB = makeLogRecord(scopeName: "scope-b", scopeVersion: "2.0.0", resource: resource)

        let resourceLogs = LogRecordAdapter.toResourceLogs([logA, logB])

        #expect(resourceLogs.count == 1)
        #expect(resourceLogs.first?.scopeLogs.count == 2)
        let scopeNames = resourceLogs.first?.scopeLogs.compactMap { $0.scope?.name } ?? []
        #expect(Set(scopeNames) == Set(["scope-a", "scope-b"]))
    }
}


// MARK: - No-Op Span Exporter

private class NoOpSpanExporter: SpanExporter {
    func export(spans _: [SpanData], explicitTimeout _: TimeInterval?) -> SpanExporterResultCode {
        .success
    }

    func flush(explicitTimeout _: TimeInterval?) -> SpanExporterResultCode {
        .success
    }

    func shutdown(explicitTimeout _: TimeInterval?) {}
}
