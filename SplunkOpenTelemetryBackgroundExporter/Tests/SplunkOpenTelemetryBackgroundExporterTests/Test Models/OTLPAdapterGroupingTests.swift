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

    private func makeSpanData(
        scopeName: String,
        scopeVersion: String,
        schemaUrl: String? = nil,
        scopeAttributes: [String: AttributeValue]? = nil
    ) -> SpanData {
        let exporter = NoOpSpanExporter()
        let processor = SimpleSpanProcessor(spanExporter: exporter)
        let tracerProvider = TracerProviderBuilder()
            .add(spanProcessor: processor)
            .build()

        let tracer = tracerProvider.get(
            instrumentationName: scopeName,
            instrumentationVersion: scopeVersion,
            schemaUrl: schemaUrl,
            attributes: scopeAttributes
        )
        let span = tracer.spanBuilder(spanName: "test-span-\(scopeName)").startSpan()
        span.end()

        guard let readableSpan = span as? ReadableSpan else {
            fatalError("Could not get SpanData from span")
        }

        return readableSpan.toSpanData()
    }

    private func makeLogRecord(scope: InstrumentationScopeInfo, resource: Resource) -> ReadableLogRecord {
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

    private func makeMetricsForScopes(
        scopeA: InstrumentationScopeInfo,
        scopeB: InstrumentationScopeInfo
    ) -> [MetricData] {
        let exporter = CapturingMetricExporter()
        let reader = PeriodicMetricReaderBuilder(exporter: exporter)
            .setInterval(timeInterval: 60)
            .build()
        let meterProvider = MeterProviderSdk.builder()
            .registerMetricReader(reader: reader)
            .registerView(
                selector: InstrumentSelectorBuilder().build(),
                view: View.builder().build()
            )
            .build()

        defer {
            _ = meterProvider.shutdown()
        }

        let meterA = meterProvider.meterBuilder(name: scopeA.name)
            .setInstrumentationVersion(instrumentationVersion: scopeA.version ?? "")
            .setSchemaUrl(schemaUrl: scopeA.schemaUrl ?? "")
            .build()
        let meterB = meterProvider.meterBuilder(name: scopeB.name)
            .setInstrumentationVersion(instrumentationVersion: scopeB.version ?? "")
            .setSchemaUrl(schemaUrl: scopeB.schemaUrl ?? "")
            .build()

        let counterA = meterA.counterBuilder(name: "metric-a").build()
        let counterB = meterB.counterBuilder(name: "metric-b").build()
        counterA.add(value: 1)
        counterB.add(value: 1)

        guard meterProvider.forceFlush() == .success else {
            fatalError("Failed to flush metrics")
        }

        let metricNames = Set(["metric-a", "metric-b"])
        return exporter.metrics.filter { metricNames.contains($0.name) }
    }

    private func makeLogRecord(scopeName: String, scopeVersion: String, resource: Resource) -> ReadableLogRecord {
        makeLogRecord(
            scope: InstrumentationScopeInfo(name: scopeName, version: scopeVersion),
            resource: resource
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
    func spanAdapterGroupsByFullScopeIdentity() {
        let spanA = makeSpanData(
            scopeName: "shared-scope",
            scopeVersion: "1.0.0",
            schemaUrl: "https://example.com/schema/a",
            scopeAttributes: ["scope.attr": .string("value-a")]
        )
        let spanB = makeSpanData(
            scopeName: "shared-scope",
            scopeVersion: "1.0.0",
            schemaUrl: "https://example.com/schema/b",
            scopeAttributes: ["scope.attr": .string("value-b")]
        )

        let resourceSpans = SpanDataAdapter.toResourceSpans([spanA, spanB])
        let scopeSpans = resourceSpans.first?.scopeSpans ?? []

        #expect(resourceSpans.count == 1)
        #expect(scopeSpans.count == 2)
        #expect(Set(scopeSpans.compactMap { $0.schemaUrl }) == Set(["https://example.com/schema/a", "https://example.com/schema/b"]))

        let scopeAttributeValues: Set<String> = Set(scopeSpans.compactMap { scopeSpans -> String? in
            guard let scopeAttribute = scopeSpans.scope?.attributes?.first(where: { $0.key == "scope.attr" }) else {
                return nil
            }
            guard case let .stringValue(value) = scopeAttribute.value else {
                return nil
            }
            return value
        })
        let expectedScopeAttributeValues: Set<String> = ["value-a", "value-b"]
        #expect(scopeAttributeValues == expectedScopeAttributeValues)
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

    @Test
    func logAdapterGroupsByFullScopeIdentity() {
        let resource = Resource(attributes: ["service.name": .string("test")])
        let scopeA = InstrumentationScopeInfo(
            name: "shared-scope",
            version: "1.0.0",
            schemaUrl: "https://example.com/schema/a",
            attributes: ["scope.attr": .string("value-a")]
        )
        let scopeB = InstrumentationScopeInfo(
            name: "shared-scope",
            version: "1.0.0",
            schemaUrl: "https://example.com/schema/b",
            attributes: ["scope.attr": .string("value-b")]
        )

        let logA = makeLogRecord(scope: scopeA, resource: resource)
        let logB = makeLogRecord(scope: scopeB, resource: resource)

        let resourceLogs = LogRecordAdapter.toResourceLogs([logA, logB])
        let scopeLogs = resourceLogs.first?.scopeLogs ?? []
        let schemaUrls = Set(scopeLogs.compactMap { $0.schemaUrl })
        let expectedSchemaUrls: Set<String> = [scopeA.schemaUrl, scopeB.schemaUrl]
            .compactMap { $0 }
            .reduce(into: Set<String>()) { set, value in
                set.insert(value)
            }

        #expect(resourceLogs.count == 1)
        #expect(scopeLogs.count == 2)
        #expect(schemaUrls == expectedSchemaUrls)

        let scopeAttributeValues: Set<String> = Set(scopeLogs.compactMap { scopeLogs -> String? in
            guard let scopeAttribute = scopeLogs.scope?.attributes?.first(where: { $0.key == "scope.attr" }) else {
                return nil
            }
            guard case let .stringValue(value) = scopeAttribute.value else {
                return nil
            }
            return value
        })
        let expectedScopeAttributeValues: Set<String> = ["value-a", "value-b"]
        #expect(scopeAttributeValues == expectedScopeAttributeValues)
    }

    @Test
    func metricAdapterGroupsByFullScopeIdentity() {
        let scopeA = InstrumentationScopeInfo(
            name: "shared-scope",
            version: "1.0.0",
            schemaUrl: "https://example.com/schema/a"
        )
        let scopeB = InstrumentationScopeInfo(
            name: "shared-scope",
            version: "1.0.0",
            schemaUrl: "https://example.com/schema/b"
        )
        let metricData = makeMetricsForScopes(scopeA: scopeA, scopeB: scopeB)

        #expect(metricData.count == 2)

        let resourceMetrics = MetricDataAdapter.toResourceMetrics(metricData)
        let scopeMetrics = resourceMetrics.first?.scopeMetrics ?? []

        #expect(resourceMetrics.count == 1)
        #expect(scopeMetrics.count == 2)
        #expect(Set(scopeMetrics.compactMap { $0.schemaUrl }) == Set(["https://example.com/schema/a", "https://example.com/schema/b"]))
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


// MARK: - Capturing Metric Exporter

private final class CapturingMetricExporter: MetricExporter {
    private let lock = NSLock()
    private var exportedMetrics: [MetricData] = []

    var metrics: [MetricData] {
        lock.lock()
        defer { lock.unlock() }
        return exportedMetrics
    }

    func export(metrics: [MetricData]) -> ExportResult {
        lock.lock()
        defer { lock.unlock() }
        exportedMetrics = metrics
        return .success
    }

    func flush() -> ExportResult {
        .success
    }

    func shutdown() -> ExportResult {
        .success
    }

    func getAggregationTemporality(for _: InstrumentType) -> AggregationTemporality {
        .delta
    }
}
