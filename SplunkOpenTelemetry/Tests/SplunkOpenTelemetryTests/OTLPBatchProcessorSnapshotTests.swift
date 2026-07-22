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

@Suite
struct OTLPBatchProcessorSnapshotTests {

    @Test
    func snapshotDrainLeavesSpansAddedDuringExportQueued() {
        let exporter = SnapshotAppendingExporter()
        let core = BatchSpanProcessorCore(
            spanExporter: exporter,
            scheduleDelay: 3_600,
            maxExportBatchSize: 100,
            maxQueueSize: 2_048
        )
        core.timer?.cancel()

        let tracer = TracerProviderBuilder()
            .build()
            .get(instrumentationName: "batch-snapshot-test", instrumentationVersion: "1.0")

        appendSpans(0 ..< 150, to: core, using: tracer)
        exporter.onFirstExport = {
            appendSpans(150 ..< 200, to: core, using: tracer)
        }

        core.drainSnapshot(deadline: nil, requeueOnFailure: true)

        #expect(exporter.exportAttemptCount == 2)
        #expect(exporter.successfulSpanCount == 150)
        #expect(core.queue.count == 50)
    }

    private func appendSpans(_ range: Range<Int>, to core: BatchSpanProcessorCore, using tracer: Tracer) {
        for index in range {
            let span = tracer.spanBuilder(spanName: "span-\(index)").startSpan()
            span.end()
            if let readable = span as? ReadableSpan {
                _ = core.queue.append(readable)
            }
        }
    }
}


private final class SnapshotAppendingExporter: SpanExporter {
    private var exportCount = 0
    private var spanCount = 0

    var onFirstExport: (() -> Void)?

    var exportAttemptCount: Int {
        exportCount
    }

    var successfulSpanCount: Int {
        spanCount
    }

    func export(spans: [SpanData], explicitTimeout _: TimeInterval?) -> SpanExporterResultCode {
        exportCount += 1
        if exportCount == 1 {
            onFirstExport?()
        }
        spanCount += spans.count
        return .success
    }

    func flush(explicitTimeout _: TimeInterval?) -> SpanExporterResultCode {
        .success
    }

    func shutdown(explicitTimeout _: TimeInterval?) {}
}
