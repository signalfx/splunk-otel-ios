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
    func exportUsesInjectedImmediateTracerProvider() {
        let spanExporter = BatchProcessorTestExporter()
        let tracerProvider = TracerProviderBuilder()
            .add(spanProcessor: OTLPImmediateSpanProcessor(spanExporter: spanExporter))
            .build()
        let exporter = OTLPLogToSpanExporter(
            agentVersion: "1.0.0",
            tracerProvider: tracerProvider
        )

        let result = exporter.export(logRecords: [makeLogRecord()], explicitTimeout: nil)

        #expect(result == .success)
        #expect(spanExporter.successfulSpanNames == ["test.event"])
    }

    @Test
    func convenienceInitializerResolvesGlobalTracerProviderAtExportTime() {
        let previousTracerProvider = OpenTelemetry.instance.tracerProvider
        let exporter = OTLPLogToSpanExporter(agentVersion: "1.0.0")
        let spanExporter = BatchProcessorTestExporter()
        let tracerProvider = TracerProviderBuilder()
            .add(spanProcessor: OTLPImmediateSpanProcessor(spanExporter: spanExporter))
            .build()

        OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)
        defer {
            OpenTelemetry.registerTracerProvider(tracerProvider: previousTracerProvider)
        }

        let result = exporter.export(logRecords: [makeLogRecord()], explicitTimeout: nil)

        #expect(result == .success)
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
