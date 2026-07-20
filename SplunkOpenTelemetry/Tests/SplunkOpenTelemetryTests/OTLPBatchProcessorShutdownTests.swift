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
struct OTLPBatchProcessorShutdownTests {

    @Test
    func shutdownFromMainThreadReturnsWithoutWaitingForDrain() {
        let exporter = FirstExportBlockingExporter()
        let processor = OTLPBatchSpanProcessor(
            spanExporter: exporter,
            scheduleDelay: 3_600,
            maxExportBatchSize: 100,
            maxQueueSize: 2_048
        )
        let tracer = makeTracer(for: processor)

        endSpans(0 ..< 100, using: tracer)
        #expect(exporter.waitUntilFirstExportStarts(timeout: 5) == .success)
        endSpans(100 ..< 105, using: tracer)

        let shutdownReturned = DispatchSemaphore(value: 0)
        DispatchQueue.main.async {
            processor.shutdown()
            shutdownReturned.signal()
        }

        #expect(shutdownReturned.wait(timeout: .now() + 1) == .success)

        exporter.releaseFirstExport()
        #expect(waitUntil(timeout: 5) { exporter.receivedSpanCount == 105 })
    }

    private func makeTracer(for processor: OTLPBatchSpanProcessor) -> Tracer {
        TracerProviderBuilder()
            .add(spanProcessor: processor)
            .build()
            .get(instrumentationName: "batch-shutdown-test", instrumentationVersion: "1.0")
    }

    private func endSpans(_ range: Range<Int>, using tracer: Tracer) {
        for index in range {
            tracer.spanBuilder(spanName: "span-\(index)").startSpan().end()
        }
    }

    private func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return true
            }

            Thread.sleep(forTimeInterval: 0.01)
        }

        return condition()
    }
}
