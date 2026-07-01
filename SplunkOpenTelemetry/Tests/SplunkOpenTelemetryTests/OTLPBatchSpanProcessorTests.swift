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
        let (provider, _, tracer) = makeProvider(
            exporter: exporter,
            configuration: configuration(scheduleDelay: 60, wakeThreshold: 100)
        )
        defer { provider.shutdown() }

        emitSpans(count: 99, tracer: tracer)
        #expect(exporter.successfulSpanCount == 0)

        emitSpans(count: 1, tracer: tracer, startingAt: 99)

        #expect(exporter.waitForExport(timeout: 2) == .success)
        #expect(exporter.successfulSpanCount == 100)
        #expect(exporter.batches.allSatisfy { $0.count <= 100 })
    }

    @Test
    func exportsPartialBatchOnTimer() {
        let exporter = BatchProcessorTestExporter()
        let (provider, _, tracer) = makeProvider(
            exporter: exporter,
            configuration: configuration(scheduleDelay: 0.05, wakeThreshold: 100)
        )
        defer { provider.shutdown() }

        emitSpans(count: 1, tracer: tracer)

        #expect(exporter.waitForExport(timeout: 1) == .success)
        #expect(exporter.successfulSpanCount == 1)
    }

    @Test
    func forceFlushExportsPartialBatchAndFlushesExporter() {
        let exporter = BatchProcessorTestExporter()
        let (provider, _, tracer) = makeProvider(
            exporter: exporter,
            configuration: configuration(scheduleDelay: 60, wakeThreshold: 100)
        )
        defer { provider.shutdown() }

        emitSpans(count: 12, tracer: tracer)
        provider.forceFlush(timeout: 2)

        #expect(exporter.successfulSpanCount == 12)
        #expect(exporter.flushCount == 1)
    }


    // MARK: - Loss prevention

    @Test
    func immediateThousandSpanBurstExportsWithoutLoss() {
        let exporter = BatchProcessorTestExporter()
        let (provider, processor, tracer) = makeProvider(
            exporter: exporter,
            configuration: configuration(
                scheduleDelay: 60,
                wakeThreshold: 100,
                maxQueueSize: 2_048,
                maxExportBatchSize: 100
            )
        )
        defer { provider.shutdown() }

        emitSpans(count: 1_000, tracer: tracer)
        provider.forceFlush(timeout: 10)

        #expect(exporter.successfulSpanCount == 1_000)
        #expect(Set(exporter.successfulSpanNames).count == 1_000)
        #expect(exporter.batches.count == 10)
        #expect(exporter.batches.allSatisfy { $0.count <= 100 })
        #expect(processor.totalDroppedSpans == 0)
        #expect(processor.queuedSpanCount == 0)
    }

    @Test
    func failedExportIsRetriedWithoutLosingSpans() {
        let exporter = BatchProcessorTestExporter(results: [.failure, .success])
        let (provider, processor, tracer) = makeProvider(
            exporter: exporter,
            configuration: configuration(scheduleDelay: 60, wakeThreshold: 100)
        )
        defer { provider.shutdown() }

        emitSpans(count: 100, tracer: tracer)
        #expect(exporter.waitForExport(timeout: 2) == .success)

        provider.forceFlush(timeout: 2)

        #expect(exporter.exportAttemptCount == 2)
        #expect(exporter.successfulSpanCount == 100)
        #expect(processor.totalDroppedSpans == 0)
        #expect(processor.queuedSpanCount == 0)
    }

    @Test
    func inFlightSpansCountTowardQueueCapacity() {
        let exporter = BatchProcessorTestExporter(blockExports: true)
        let (provider, processor, tracer) = makeProvider(
            exporter: exporter,
            configuration: configuration(
                scheduleDelay: 60,
                wakeThreshold: 10,
                maxQueueSize: 10,
                maxExportBatchSize: 10
            )
        )
        defer { provider.shutdown() }

        emitSpans(count: 10, tracer: tracer)
        #expect(exporter.waitUntilExportStarts(timeout: 2) == .success)

        emitSpans(count: 5, tracer: tracer, startingAt: 10)
        #expect(processor.totalDroppedSpans == 5)
        #expect(processor.queuedSpanCount == 10)

        exporter.resumeExports()
        provider.forceFlush(timeout: 2)

        #expect(exporter.successfulSpanCount == 10)
    }


    // MARK: - Shutdown

    @Test
    func shutdownDrainsOnceAndRejectsLaterSpans() {
        let exporter = BatchProcessorTestExporter()
        let (provider, _, tracer) = makeProvider(
            exporter: exporter,
            configuration: configuration(scheduleDelay: 60, wakeThreshold: 100)
        )

        emitSpans(count: 10, tracer: tracer)
        provider.shutdown()
        provider.shutdown()
        emitSpans(count: 1, tracer: tracer, startingAt: 10)

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
    ) -> (TracerProviderSdk, SplunkBatchSpanProcessor, Tracer) {
        let processor = SplunkBatchSpanProcessor(
            spanExporter: exporter,
            configuration: configuration
        )
        let provider = TracerProviderBuilder()
            .add(spanProcessor: processor)
            .build()
        let tracer = provider.get(instrumentationName: "SplunkBatchSpanProcessorTests")

        return (provider, processor, tracer)
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

private final class BatchProcessorTestExporter: SpanExporter {
    private let lock = NSLock()
    private let exportCompleted = DispatchSemaphore(value: 0)
    private let exportStarted = DispatchSemaphore(value: 0)
    private let exportResume = DispatchSemaphore(value: 0)
    private let blockExports: Bool

    private var results: [SpanExporterResultCode]
    private var storedBatches: [[SpanData]] = []
    private var storedSuccessfulSpans: [SpanData] = []
    private var storedExportAttemptCount = 0
    private var storedFlushCount = 0
    private var storedShutdownCount = 0

    init(
        results: [SpanExporterResultCode] = [],
        blockExports: Bool = false
    ) {
        self.results = results
        self.blockExports = blockExports
    }

    var batches: [[SpanData]] {
        lock.withBatchProcessorLock { storedBatches }
    }

    var successfulSpanNames: [String] {
        lock.withBatchProcessorLock { storedSuccessfulSpans.map(\.name) }
    }

    var successfulSpanCount: Int {
        lock.withBatchProcessorLock { storedSuccessfulSpans.count }
    }

    var exportAttemptCount: Int {
        lock.withBatchProcessorLock { storedExportAttemptCount }
    }

    var flushCount: Int {
        lock.withBatchProcessorLock { storedFlushCount }
    }

    var shutdownCount: Int {
        lock.withBatchProcessorLock { storedShutdownCount }
    }

    func export(spans: [SpanData], explicitTimeout _: TimeInterval?) -> SpanExporterResultCode {
        exportStarted.signal()
        if blockExports {
            exportResume.wait()
        }

        let result = lock.withBatchProcessorLock {
            storedExportAttemptCount += 1
            storedBatches.append(spans)

            let result = results.isEmpty ? SpanExporterResultCode.success : results.removeFirst()
            if result == .success {
                storedSuccessfulSpans.append(contentsOf: spans)
            }
            return result
        }

        exportCompleted.signal()
        return result
    }

    func flush(explicitTimeout _: TimeInterval?) -> SpanExporterResultCode {
        lock.withBatchProcessorLock {
            storedFlushCount += 1
        }
        return .success
    }

    func shutdown(explicitTimeout _: TimeInterval?) {
        lock.withBatchProcessorLock {
            storedShutdownCount += 1
        }
    }

    func waitForExport(timeout: TimeInterval) -> DispatchTimeoutResult {
        exportCompleted.wait(timeout: .now() + timeout)
    }

    func waitUntilExportStarts(timeout: TimeInterval) -> DispatchTimeoutResult {
        exportStarted.wait(timeout: .now() + timeout)
    }

    func resumeExports() {
        exportResume.signal()
    }
}

private extension NSLock {
    func withBatchProcessorLock<T>(_ work: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try work()
    }
}
