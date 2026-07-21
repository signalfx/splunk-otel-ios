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
struct OTLPBatchSpanProcessorFlushResultTests {
    @Test
    func mainThreadFlushReportsScheduled() {
        let exporter = BatchProcessorTestExporter()
        let processor = OTLPBatchSpanProcessor(
            spanExporter: exporter,
            scheduleDelay: 3_600
        )
        let tracer = TracerProviderBuilder()
            .add(spanProcessor: processor)
            .build()
            .get(instrumentationName: "BatchSpanProcessorFlushResultTests")

        tracer.spanBuilder(spanName: "main-thread.span").startSpan().end()

        let forceFlushReturned = DispatchSemaphore(value: 0)
        let resultQueue = DispatchQueue(label: "com.splunk.batch-processor-test.force-flush-result")
        var flushResult = false

        DispatchQueue.main.async {
            let result = processor.forceFlushResult(timeout: 1)
            resultQueue.sync {
                flushResult = result
            }
            forceFlushReturned.signal()
        }

        #expect(forceFlushReturned.wait(timeout: .now() + 1) == .success)
        #expect(resultQueue.sync { flushResult })
        #expect(exporter.waitForExport(timeout: 1) == .success)
        #expect(exporter.successfulSpanNames == ["main-thread.span"])
        #expect(exporter.flushCount == 1)
    }
}
