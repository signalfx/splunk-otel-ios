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
struct OTLPBatchSpanProcessorTests {

    // MARK: - Inline types

    private struct ProviderContext {
        let provider: TracerProviderSdk
        let processor: OTLPBatchSpanProcessor
        let tracer: Tracer
    }

    // MARK: - Configuration

    @Test
    func productionConfigurationMatchesMeasuredSettings() {
        let configuration = TraceExportBatchConfiguration.production(exportTimeout: 10)

        #expect(configuration.scheduleDelay == 0.5)
        #expect(configuration.wakeThreshold == 100)
        #expect(configuration.maxExportBatchSize == 100)
        #expect(configuration.maxQueueSize == 2_048)
        #expect(configuration.exportTimeout == 10)
    }


    // MARK: - Export triggers

    @Test
    func exportsWhenWakeThresholdIsReached() {
        let exporter = BatchProcessorTestExporter()
        let context = makeProvider(
            exporter: exporter,
            configuration: configuration(scheduleDelay: 60, wakeThreshold: 100)
        )
        defer { context.provider.shutdown() }

        emitSpans(count: 99, tracer: context.tracer)
        #expect(exporter.successfulSpanCount == 0)

        emitSpans(count: 1, tracer: context.tracer, startingAt: 99)

        #expect(exporter.waitForExport(timeout: 2) == .success)
        #expect(exporter.successfulSpanCount == 100)
        #expect(exporter.batches.allSatisfy { $0.count <= 100 })
    }

    @Test
    func exportsPartialBatchOnTimer() {
        let exporter = BatchProcessorTestExporter()
        let context = makeProvider(
            exporter: exporter,
            configuration: configuration(scheduleDelay: 0.05, wakeThreshold: 100)
        )
        defer { context.provider.shutdown() }

        emitSpans(count: 1, tracer: context.tracer)

        #expect(exporter.waitForExport(timeout: 1) == .success)
        #expect(exporter.successfulSpanCount == 1)
    }

    @Test
    func delayedDrainStopsWhenQueueIsEmptyAndRearmsForNewSpans() {
        let exporter = BatchProcessorTestExporter()
        let context = makeProvider(
            exporter: exporter,
            configuration: configuration(scheduleDelay: 0.05, wakeThreshold: 100)
        )
        defer { context.provider.shutdown() }

        emitSpans(count: 1, tracer: context.tracer)
        #expect(context.processor.isDelayedDrainScheduled)
        #expect(exporter.waitForExport(timeout: 1) == .success)
        #expect(context.processor.isDelayedDrainScheduled == false)

        emitSpans(count: 1, tracer: context.tracer, startingAt: 1)
        #expect(context.processor.isDelayedDrainScheduled)
        #expect(exporter.waitForExport(timeout: 1) == .success)
        #expect(exporter.successfulSpanCount == 2)
        #expect(context.processor.isDelayedDrainScheduled == false)
    }

    @Test
    func forceFlushExportsPartialBatchAndFlushesExporter() {
        let exporter = BatchProcessorTestExporter()
        let context = makeProvider(
            exporter: exporter,
            configuration: configuration(scheduleDelay: 60, wakeThreshold: 100)
        )
        defer { context.provider.shutdown() }

        emitSpans(count: 12, tracer: context.tracer)
        context.provider.forceFlush(timeout: 2)

        #expect(exporter.successfulSpanCount == 12)
        #expect(exporter.flushCount == 1)
    }

    @Test
    func persistenceOnlyDrainDoesNotFlushExporter() {
        let exporter = BatchProcessorTestExporter()
        let context = makeProvider(
            exporter: exporter,
            configuration: configuration(scheduleDelay: 60, wakeThreshold: 100)
        )
        defer { context.provider.shutdown() }

        emitSpans(count: 12, tracer: context.tracer)
        context.processor.persistPendingSpans(timeout: 2)

        #expect(exporter.successfulSpanCount == 12)
        #expect(exporter.flushCount == 0)
        #expect(context.processor.queuedSpanCount == 0)
        #expect(context.processor.isDelayedDrainScheduled == false)
    }


    // MARK: - Loss prevention

    @Test
    func immediateThousandSpanBurstExportsWithoutLoss() {
        let exporter = BatchProcessorTestExporter()
        let context = makeProvider(
            exporter: exporter,
            configuration: configuration(
                scheduleDelay: 60,
                wakeThreshold: 100,
                maxQueueSize: 2_048,
                maxExportBatchSize: 100
            )
        )
        defer { context.provider.shutdown() }

        emitSpans(count: 1_000, tracer: context.tracer)
        context.provider.forceFlush(timeout: 10)

        #expect(exporter.successfulSpanCount == 1_000)
        #expect(Set(exporter.successfulSpanNames).count == 1_000)
        #expect(exporter.batches.count == 10)
        #expect(exporter.batches.allSatisfy { $0.count <= 100 })
        #expect(context.processor.totalDroppedSpans == 0)
        #expect(context.processor.queuedSpanCount == 0)
    }

    @Test
    func failedExportIsRetriedWithoutLosingSpans() {
        let exporter = BatchProcessorTestExporter(results: [.failure, .success])
        let context = makeProvider(
            exporter: exporter,
            configuration: configuration(scheduleDelay: 60, wakeThreshold: 100)
        )
        defer { context.provider.shutdown() }

        emitSpans(count: 100, tracer: context.tracer)
        #expect(exporter.waitForExport(timeout: 2) == .success)

        context.provider.forceFlush(timeout: 2)

        #expect(exporter.exportAttemptCount == 2)
        #expect(exporter.successfulSpanCount == 100)
        #expect(context.processor.totalDroppedSpans == 0)
        #expect(context.processor.queuedSpanCount == 0)
    }

    @Test
    func failedExportRequeuesAheadOfNewSpansInFIFOOrder() {
        let exporter = BatchProcessorTestExporter(results: [.failure, .success, .success])
        let context = makeProvider(
            exporter: exporter,
            configuration: configuration(
                scheduleDelay: 60,
                wakeThreshold: 4,
                maxQueueSize: 8,
                maxExportBatchSize: 4
            )
        )
        defer { context.provider.shutdown() }

        emitSpans(count: 4, tracer: context.tracer)
        #expect(exporter.waitForExport(timeout: 2) == .success)

        emitSpans(count: 4, tracer: context.tracer, startingAt: 4)
        context.provider.forceFlush(timeout: 2)

        #expect(exporter.successfulSpanNames == (0 ..< 8).map { "batch-test-\($0)" })
        #expect(context.processor.totalDroppedSpans == 0)
        #expect(context.processor.queuedSpanCount == 0)
    }

    @Test
    func inFlightSpansCountTowardQueueCapacity() {
        let exporter = BatchProcessorTestExporter(blockExports: true)
        let context = makeProvider(
            exporter: exporter,
            configuration: configuration(
                scheduleDelay: 60,
                wakeThreshold: 10,
                maxQueueSize: 10,
                maxExportBatchSize: 10
            )
        )
        defer { context.provider.shutdown() }

        emitSpans(count: 10, tracer: context.tracer)
        #expect(exporter.waitUntilExportStarts(timeout: 2) == .success)

        emitSpans(count: 5, tracer: context.tracer, startingAt: 10)
        #expect(context.processor.totalDroppedSpans == 5)
        #expect(context.processor.queuedSpanCount == 10)

        exporter.resumeExports()
        context.provider.forceFlush(timeout: 2)

        #expect(exporter.successfulSpanCount == 10)
    }


    // MARK: - Shutdown

    @Test
    func shutdownDrainsOnceAndRejectsLaterSpans() {
        let exporter = BatchProcessorTestExporter()
        let context = makeProvider(
            exporter: exporter,
            configuration: configuration(scheduleDelay: 60, wakeThreshold: 100)
        )

        emitSpans(count: 10, tracer: context.tracer)
        context.provider.shutdown()
        context.provider.shutdown()
        emitSpans(count: 1, tracer: context.tracer, startingAt: 10)

        #expect(exporter.successfulSpanCount == 10)
        #expect(exporter.flushCount == 1)
        #expect(exporter.shutdownCount == 1)
    }


    // MARK: - Helpers

    private func configuration(
        scheduleDelay: TimeInterval,
        wakeThreshold: Int,
        maxQueueSize: Int = 2_048,
        maxExportBatchSize: Int = 100
    ) -> TraceExportBatchConfiguration {
        TraceExportBatchConfiguration(
            scheduleDelay: scheduleDelay,
            wakeThreshold: wakeThreshold,
            maxQueueSize: maxQueueSize,
            maxExportBatchSize: maxExportBatchSize,
            exportTimeout: 10
        )
    }

    private func makeProvider(
        exporter: SpanExporter,
        configuration: TraceExportBatchConfiguration
    ) -> ProviderContext {
        let processor = OTLPBatchSpanProcessor(
            spanExporter: exporter,
            configuration: configuration
        )
        let provider = TracerProviderBuilder()
            .add(spanProcessor: processor)
            .build()
        let tracer = provider.get(instrumentationName: "OTLPBatchSpanProcessorTests")

        return ProviderContext(
            provider: provider,
            processor: processor,
            tracer: tracer
        )
    }

    private func emitSpans(
        count: Int,
        tracer: Tracer,
        startingAt startIndex: Int = 0
    ) {
        for index in startIndex ..< startIndex + count {
            let span = tracer.spanBuilder(spanName: "batch-test-\(index)").startSpan()
            span.end()
        }
    }
}
