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
import Testing

@testable import SplunkOpenTelemetry

@Suite(.serialized)
struct OTLPBatchSpanProcessorPersistenceTests {
    @Test
    func specificSpanPersistenceReportsSuccessOnlyAfterThatSpanIsExported() {
        let exporter = BatchProcessorTestExporter()
        let processor = OTLPBatchSpanProcessor(
            spanExporter: exporter,
            scheduleDelay: Self.neverFires,
            maxExportBatchSize: Self.hugeBatch,
            maxQueueSize: 2_048
        )
        let tracer = makeTracer(for: processor)
        let completed = DispatchSemaphore(value: 0)

        processor.persistSpan(
            emitting: {
                let span = tracer.spanBuilder(spanName: "crash-span").startSpan()
                let spanId = span.context.spanId
                span.end()
                return spanId
            },
            timeout: 1,
            completion: { succeeded in
                #expect(succeeded)
                completed.signal()
            }
        )

        #expect(completed.wait(timeout: .now() + 1) == .success)
        #expect(exporter.successfulSpanNames == ["crash-span"])
    }

    @Test
    func specificSpanPersistenceReportsFailureWhenThatSpanIsDroppedByFullQueue() {
        let batchSize = 10
        let exporter = BatchProcessorTestExporter(
            results: [.success, .failure],
            blockExports: true
        )
        let processor = OTLPBatchSpanProcessor(
            spanExporter: exporter,
            scheduleDelay: Self.neverFires,
            maxExportBatchSize: batchSize,
            maxQueueSize: batchSize
        )
        let tracer = makeTracer(for: processor)
        let completed = DispatchSemaphore(value: 0)

        // Occupy the processor queue with the first batch, then fill the in-memory queue again.
        endSpans(batchSize, using: tracer)
        #expect(exporter.waitUntilExportStarts(timeout: 1) == .success)
        endSpans(batchSize, using: tracer)

        processor.persistSpan(
            emitting: {
                let span = tracer.spanBuilder(spanName: "crash-span").startSpan()
                let spanId = span.context.spanId
                span.end()
                return spanId
            },
            timeout: 1,
            completion: { succeeded in
                #expect(!succeeded)
                completed.signal()
            }
        )

        // The queued batch fails and is restored at full capacity before the crash span is emitted.
        exporter.resumeExports()
        #expect(exporter.waitUntilExportStarts(timeout: 1) == .success)
        exporter.resumeExports()

        #expect(completed.wait(timeout: .now() + 1) == .success)
        #expect(!exporter.successfulSpanNames.contains("crash-span"))
        #expect(exporter.exportAttemptCount == 2)
    }

    private static let neverFires: TimeInterval = 3_600
    private static let hugeBatch = 1_000_000

    private func makeTracer(for processor: OTLPBatchSpanProcessor) -> Tracer {
        TracerProviderTestBuilder
            .buildBatch(processor: processor)
            .get(instrumentationName: "test", instrumentationVersion: "1.0")
    }

    private func endSpans(_ count: Int, using tracer: Tracer) {
        for index in 0 ..< count {
            tracer.spanBuilder(spanName: "span-\(index)").startSpan().end()
        }
    }
}
