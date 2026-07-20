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

@testable import SplunkOpenTelemetry

@Suite(.serialized)
struct OTLPLogToSpanExporterTests {

    @Test
    func exportUsesInjectedBatchTracerProvider() {
        let spanExporter = BatchProcessorTestExporter()
        let spanProcessor = OTLPBatchSpanProcessor(
            spanExporter: spanExporter,
            scheduleDelay: 5
        )
        let tracerProvider = TracerProviderBuilder()
            .add(spanProcessor: spanProcessor)
            .build()
        let exporter = OTLPLogToSpanExporter(
            agentVersion: "1.0.0",
            tracerProvider: tracerProvider
        )

        tracerProvider
            .get(instrumentationName: "DirectSpanTest")
            .spanBuilder(spanName: "direct.span")
            .startSpan()
            .end()
        let result = exporter.export(logRecords: [makeLogRecord()], explicitTimeout: nil)
        spanProcessor.forceFlush(timeout: 1)

        #expect(result == .success)
        #expect(spanExporter.waitForExport(timeout: 1) == .success)
        #expect(spanExporter.successfulSpanNames == ["direct.span", "test.event"])
        #expect(spanExporter.batches.count == 1)
    }

    @Test
    func convenienceInitializerResolvesGlobalTracerProviderAtExportTime() {
        let previousTracerProvider = OpenTelemetry.instance.tracerProvider
        let exporter = OTLPLogToSpanExporter(agentVersion: "1.0.0")
        let spanExporter = BatchProcessorTestExporter()
        let spanProcessor = OTLPBatchSpanProcessor(
            spanExporter: spanExporter,
            scheduleDelay: 5
        )
        let tracerProvider = TracerProviderBuilder()
            .add(spanProcessor: spanProcessor)
            .build()

        OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)
        defer {
            OpenTelemetry.registerTracerProvider(tracerProvider: previousTracerProvider)
        }

        let result = exporter.export(logRecords: [makeLogRecord()], explicitTimeout: nil)
        spanProcessor.forceFlush(timeout: 1)

        #expect(result == .success)
        #expect(spanExporter.waitForExport(timeout: 1) == .success)
        #expect(spanExporter.successfulSpanNames == ["test.event"])
    }

    private func makeLogRecord() -> ReadableLogRecord {
        ReadableLogRecord(
            resource: Resource(),
            instrumentationScopeInfo: InstrumentationScopeInfo(name: "test", version: "1.0.0"),
            timestamp: Date(),
            observedTimestamp: nil,
            spanContext: nil,
            severity: nil,
            body: .string("body"),
            attributes: [
                "event.name": .string("test.event"),
                "custom.attribute": .string("value")
            ]
        )
    }
}
