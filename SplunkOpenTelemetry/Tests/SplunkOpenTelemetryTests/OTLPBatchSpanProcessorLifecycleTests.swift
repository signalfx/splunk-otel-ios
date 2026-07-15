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
@preconcurrency import OpenTelemetryApi
import Testing

@testable import SplunkOpenTelemetry

#if os(iOS) || os(tvOS) || os(visionOS)
    import UIKit

    /// Serialized to keep the shared `NotificationCenter` lifecycle hooks deterministic across tests.
    @Suite(.serialized)
    struct OTLPBatchSpanProcessorLifecycleTests {

        // MARK: - Background

        @Test
        func enteringBackgroundFlushesPendingBatch() async {
            let exporter = BatchProcessorTestExporter()
            let processor = OTLPBatchSpanProcessor(
                spanExporter: exporter,
                scheduleDelay: Self.neverFires,
                maxExportBatchSize: Self.hugeBatch,
                maxQueueSize: 2_048
            )
            let tracer = makeTracer(for: processor)
            processor.registerBackgroundObserver {}

            endSpans(5, using: tracer)
            #expect(exporter.successfulSpanCount == 0)

            await postDidEnterBackgroundNotification()

            #expect(waitUntil(timeout: 5) { exporter.successfulSpanCount == 5 })
        }

        @Test
        func enteringBackgroundFlushCapturesSpansFromLaterModuleObservers() async {
            let exporter = BatchProcessorTestExporter()
            let processor = OTLPBatchSpanProcessor(
                spanExporter: exporter,
                scheduleDelay: Self.neverFires,
                maxExportBatchSize: Self.hugeBatch,
                maxQueueSize: 2_048
            )
            let tracer = makeTracer(for: processor)
            processor.registerBackgroundObserver {}

            let lateObserver = await MainActor.run {
                NotificationCenter.default.addObserver(
                    forName: UIApplication.didEnterBackgroundNotification,
                    object: nil,
                    queue: nil
                ) { _ in
                    tracer.spanBuilder(spanName: "late-background").startSpan().end()
                }
            }
            defer {
                NotificationCenter.default.removeObserver(lateObserver)
            }

            await postDidEnterBackgroundNotification()

            #expect(waitUntil(timeout: 5) { exporter.successfulSpanNames == ["late-background"] })
        }

        @Test
        func enteringBackgroundAwaitsAsyncProducerBeforeSnapshot() async {
            let exporter = BatchProcessorTestExporter()
            let processor = OTLPBatchSpanProcessor(
                spanExporter: exporter,
                scheduleDelay: Self.neverFires,
                maxExportBatchSize: Self.hugeBatch,
                maxQueueSize: 2_048
            )
            let tracer = makeTracer(for: processor)

            processor.registerBackgroundObserver {
                try? await Task.sleep(nanoseconds: 50_000_000)
                tracer.spanBuilder(spanName: "async-background").startSpan().end()
            }

            await postDidEnterBackgroundNotification()

            #expect(waitUntil(timeout: 5) { exporter.successfulSpanNames == ["async-background"] })
        }


        // MARK: - Termination

        @Test
        func terminatingFlushesPendingBatchBeforeNotificationReturns() async {
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

            processor.registerTerminationObserver {}
            await postWillTerminateNotification()

            #expect(exporter.successfulSpanCount == 5)
            #expect(exporter.exportTimeouts.count == 1)
            #expect(exporter.exportTimeouts.allSatisfy { $0 == nil })
        }

        @Test
        func terminatingRunsPrepareHookBeforeDraining() async {
            let exporter = BatchProcessorTestExporter()
            let processor = OTLPBatchSpanProcessor(
                spanExporter: exporter,
                scheduleDelay: Self.neverFires,
                maxExportBatchSize: Self.hugeBatch,
                maxQueueSize: 2_048
            )
            let tracer = makeTracer(for: processor)

            endSpans(5, using: tracer)

            processor.registerTerminationObserver {
                tracer.spanBuilder(spanName: "prepared-terminate").startSpan().end()
            }
            await postWillTerminateNotification()

            #expect(
                exporter.successfulSpanNames == [
                    "span-0",
                    "span-1",
                    "span-2",
                    "span-3",
                    "span-4",
                    "prepared-terminate"
                ]
            )
        }

        @Test
        func terminatingDropsSpansOnExportFailure() async {
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

            processor.registerTerminationObserver {}
            await postWillTerminateNotification()

            #expect(exporter.exportAttemptCount == 1)
            #expect(exporter.successfulSpanCount == 0)

            // The failed batch was dropped, so a later flush finds nothing to export.
            processor.forceFlush()
            #expect(exporter.successfulSpanCount == 0)
            #expect(exporter.exportAttemptCount == 1)
        }
    }


    // MARK: - Helpers

    extension OTLPBatchSpanProcessorLifecycleTests {

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

        private func postWillTerminateNotification() async {
            await MainActor.run {
                NotificationCenter.default.post(
                    name: UIApplication.willTerminateNotification,
                    object: nil
                )
            }
        }

        private func postDidEnterBackgroundNotification() async {
            await MainActor.run {
                NotificationCenter.default.post(
                    name: UIApplication.didEnterBackgroundNotification,
                    object: nil
                )
            }
        }
    }
#endif
