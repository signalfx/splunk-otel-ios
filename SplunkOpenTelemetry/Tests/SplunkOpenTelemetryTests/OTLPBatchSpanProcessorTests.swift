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

#if os(iOS) || os(tvOS) || os(visionOS)
    import UIKit
#endif

/// Serialized to keep timers and the shared `NotificationCenter` lifecycle hooks deterministic across tests.
@Suite(.serialized)
struct OTLPBatchSpanProcessorTests {

    // MARK: - Size trigger

    @Test
    func reachingBatchSizeFlushesImmediately() {
        let exporter = BatchProcessorTestExporter()
        let processor = OTLPBatchSpanProcessor(
            spanExporter: exporter,
            scheduleDelay: Self.neverFires,
            maxExportBatchSize: 100,
            maxQueueSize: 2_048
        )
        let tracer = makeTracer(for: processor)

        endSpans(100, using: tracer)

        #expect(waitUntil(timeout: 5) { exporter.successfulSpanCount == 100 })
        #expect(exporter.batches.contains { $0.count == 100 })
    }


    // MARK: - Interval trigger

    @Test
    func timerFlushesPartialBatch() {
        let exporter = BatchProcessorTestExporter()
        let processor = OTLPBatchSpanProcessor(
            spanExporter: exporter,
            scheduleDelay: 0.5,
            maxExportBatchSize: 100,
            maxQueueSize: 2_048
        )
        let tracer = makeTracer(for: processor)

        endSpans(5, using: tracer)

        // Fewer than a full batch: only the timer can flush these.
        #expect(waitUntil(timeout: 5) { exporter.successfulSpanCount == 5 })
        #expect(exporter.batches.allSatisfy { $0.count <= 100 })
    }


    // MARK: - Chunking

    @Test
    func spansAreExportedInBatchSizedChunks() {
        let exporter = BatchProcessorTestExporter()
        let processor = OTLPBatchSpanProcessor(
            spanExporter: exporter,
            scheduleDelay: 0.5,
            maxExportBatchSize: 100,
            maxQueueSize: 2_048
        )
        let tracer = makeTracer(for: processor)

        endSpans(150, using: tracer)

        #expect(waitUntil(timeout: 5) { exporter.successfulSpanCount == 150 })

        let batches = exporter.batches
        #expect(batches.allSatisfy { $0.count <= 100 })
        #expect(batches.contains { $0.count == 100 })
        #expect(batches.reduce(0) { $0 + $1.count } == 150)
    }


    // MARK: - Backpressure

    @Test
    func overflowingQueueDropsNewestSpans() {
        // The first export blocks, occupying the serial queue so no further draining can happen.
        // That lets us saturate the in-memory queue and observe that excess spans are dropped.
        let exporter = FirstExportBlockingExporter()
        let batch = 100
        let capacity = 100
        let processor = OTLPBatchSpanProcessor(
            spanExporter: exporter,
            scheduleDelay: Self.neverFires,
            maxExportBatchSize: batch,
            maxQueueSize: capacity
        )
        let tracer = makeTracer(for: processor)

        // Reaching the batch size kicks off a drain, which removes a full batch and then blocks.
        endSpans(batch, using: tracer)
        #expect(exporter.waitUntilFirstExportStarts(timeout: 5) == .success)

        // The queue is now empty but the serial queue is blocked: no more draining can occur.
        // Push far more than capacity; the surplus beyond `capacity` must be dropped.
        let surplus = 150
        endSpans(capacity + surplus, using: tracer)

        // While the first export is blocked, only that batch has reached the exporter.
        #expect(exporter.receivedSpanCount == batch)

        // Release the block: the buffered full batch drains, but the dropped surplus never arrives.
        exporter.releaseFirstExport()

        #expect(waitUntil(timeout: 5) { exporter.receivedSpanCount == batch + capacity })
        // Confirm spans were actually dropped rather than silently retained.
        #expect(batch + (capacity + surplus) > exporter.receivedSpanCount)
    }


    // MARK: - forceFlush

    @Test
    func forceFlushDrainsSynchronously() {
        let exporter = BatchProcessorTestExporter()
        let processor = OTLPBatchSpanProcessor(
            spanExporter: exporter,
            scheduleDelay: Self.neverFires,
            maxExportBatchSize: Self.hugeBatch,
            maxQueueSize: 2_048
        )
        let tracer = makeTracer(for: processor)

        endSpans(10, using: tracer)
        processor.forceFlush()

        // No polling: forceFlush is synchronous, so everything is exported once it returns.
        #expect(exporter.successfulSpanCount == 10)
    }


    // MARK: - Shutdown

    @Test
    func shutdownFlushesRemainderAndIsIdempotent() {
        let exporter = BatchProcessorTestExporter()
        let processor = OTLPBatchSpanProcessor(
            spanExporter: exporter,
            scheduleDelay: Self.neverFires,
            maxExportBatchSize: Self.hugeBatch,
            maxQueueSize: 2_048
        )
        let tracer = makeTracer(for: processor)

        endSpans(10, using: tracer)
        processor.shutdown()

        #expect(exporter.successfulSpanCount == 10)
        #expect(exporter.shutdownCount == 1)

        // Second shutdown is a no-op.
        processor.shutdown()
        #expect(exporter.shutdownCount == 1)

        // Spans ending after shutdown are ignored.
        endSpans(5, using: tracer)
        processor.forceFlush()
        #expect(exporter.successfulSpanCount == 10)
    }


    // MARK: - Failure handling

    @Test
    func transientExportFailureIsRequeuedAndRetried() {
        // First export fails, second succeeds. forceFlush uses the requeue-on-failure path, so the
        // batch must survive the first failure and export in full on the retry.
        let exporter = BatchProcessorTestExporter(results: [.failure, .success])
        let processor = OTLPBatchSpanProcessor(
            spanExporter: exporter,
            scheduleDelay: Self.neverFires,
            maxExportBatchSize: Self.hugeBatch,
            maxQueueSize: 2_048
        )
        let tracer = makeTracer(for: processor)

        endSpans(10, using: tracer)

        // First flush: export fails, spans are re-queued (not dropped).
        processor.forceFlush()
        #expect(exporter.successfulSpanCount == 0)
        #expect(exporter.exportAttemptCount == 1)

        // Second flush: the same 10 spans are retried and now succeed.
        processor.forceFlush()
        #expect(exporter.successfulSpanCount == 10)
        #expect(exporter.exportAttemptCount == 2)
    }

    @Test
    func persistentFailureIsNotReattemptedWithinOneScheduledFlush() {
        // Several full batches are pending and every export fails. A single coalesced flush must make
        // exactly one attempt and then stop, rather than re-exporting the re-queued front batch once
        // per pending batch.
        let exporter = BatchProcessorTestExporter(results: Array(repeating: .failure, count: 10))
        let processor = OTLPBatchSpanProcessor(
            spanExporter: exporter,
            scheduleDelay: Self.neverFires,
            maxExportBatchSize: 100,
            maxQueueSize: 2_048
        )
        let tracer = makeTracer(for: processor)

        endSpans(300, using: tracer)

        #expect(waitUntil(timeout: 5) { exporter.exportAttemptCount >= 1 })
        // Give any erroneous extra attempts a chance to happen, then confirm there was only one.
        Thread.sleep(forTimeInterval: 0.3)
        #expect(exporter.exportAttemptCount == 1)
        #expect(exporter.successfulSpanCount == 0)
    }

    @Test
    func shutdownDropsSpansOnExportFailure() {
        // On shutdown a failed export is dropped (not re-queued) so teardown always terminates.
        let exporter = BatchProcessorTestExporter(results: [.failure])
        let processor = OTLPBatchSpanProcessor(
            spanExporter: exporter,
            scheduleDelay: Self.neverFires,
            maxExportBatchSize: Self.hugeBatch,
            maxQueueSize: 2_048
        )
        let tracer = makeTracer(for: processor)

        endSpans(10, using: tracer)
        processor.shutdown()

        #expect(exporter.exportAttemptCount == 1)
        #expect(exporter.successfulSpanCount == 0)
        #expect(exporter.shutdownCount == 1)
    }

    #if os(iOS) || os(tvOS) || os(visionOS)
        @Test
        func terminatingDropsSpansOnExportFailure() {
            // Terminate drains best effort; a failed export is dropped (not re-queued), leaving the
            // buffer empty afterward since the process is going away.
            let exporter = BatchProcessorTestExporter(results: [.failure])
            let processor = OTLPBatchSpanProcessor(
                spanExporter: exporter,
                scheduleDelay: Self.neverFires,
                maxExportBatchSize: Self.hugeBatch,
                maxQueueSize: 2_048
            )
            let tracer = makeTracer(for: processor)

            endSpans(5, using: tracer)

            NotificationCenter.default.post(
                name: UIApplication.willTerminateNotification,
                object: nil
            )

            #expect(waitUntil(timeout: 5) { exporter.exportAttemptCount == 1 })
            #expect(exporter.successfulSpanCount == 0)

            // The failed batch was dropped, so a later flush finds nothing to export.
            processor.forceFlush()
            #expect(exporter.successfulSpanCount == 0)
            #expect(exporter.exportAttemptCount == 1)
        }
    #endif


    // MARK: - Sampling

    @Test
    func unsampledSpansAreNotExported() {
        let exporter = BatchProcessorTestExporter()
        let processor = OTLPBatchSpanProcessor(
            spanExporter: exporter,
            scheduleDelay: 0.5,
            maxExportBatchSize: 100,
            maxQueueSize: 2_048
        )
        let tracer =
            TracerProviderTestBuilder
            .buildBatchNeverSampled(processor: processor)
            .get(instrumentationName: "test", instrumentationVersion: "1.0")

        endSpans(20, using: tracer)

        // Give the timer a chance to (incorrectly) flush, then confirm nothing was exported.
        _ = waitUntil(timeout: 1) { exporter.successfulSpanCount > 0 }
        processor.forceFlush()
        #expect(exporter.successfulSpanCount == 0)
    }


    // MARK: - Lifecycle

    #if os(iOS) || os(tvOS) || os(visionOS)
        @Test
        func enteringBackgroundFlushesPendingBatch() {
            let exporter = BatchProcessorTestExporter()
            let processor = OTLPBatchSpanProcessor(
                spanExporter: exporter,
                scheduleDelay: Self.neverFires,
                maxExportBatchSize: Self.hugeBatch,
                maxQueueSize: 2_048
            )
            let tracer = makeTracer(for: processor)

            endSpans(5, using: tracer)
            #expect(exporter.successfulSpanCount == 0)

            NotificationCenter.default.post(
                name: UIApplication.didEnterBackgroundNotification,
                object: nil
            )

            #expect(waitUntil(timeout: 5) { exporter.successfulSpanCount == 5 })
        }

        @Test
        func terminatingFlushesPendingBatchSynchronously() {
            let exporter = BatchProcessorTestExporter()
            let processor = OTLPBatchSpanProcessor(
                spanExporter: exporter,
                scheduleDelay: Self.neverFires,
                maxExportBatchSize: Self.hugeBatch,
                maxQueueSize: 2_048
            )
            let tracer = makeTracer(for: processor)

            endSpans(5, using: tracer)
            #expect(exporter.successfulSpanCount == 0)

            // The terminate observer drains synchronously, so the buffer is persisted by the time
            // `post` returns; no polling required.
            NotificationCenter.default.post(
                name: UIApplication.willTerminateNotification,
                object: nil
            )

            #expect(exporter.successfulSpanCount == 5)
        }
    #endif
}


// MARK: - Helpers

extension OTLPBatchSpanProcessorTests {

    /// A schedule delay large enough that the periodic timer never fires during a test.
    private static let neverFires: TimeInterval = 3_600

    /// A batch size large enough that the size threshold never triggers during a test.
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

    @discardableResult
    private func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return true
            }
            Thread.sleep(forTimeInterval: 0.02)
        }
        return condition()
    }
}
