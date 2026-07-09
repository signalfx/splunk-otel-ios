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
struct OTLPBatchProcessorSafetyTests {

    // MARK: - Force flush

    @Test
    func forceFlushIsReentrantAndForwardsTimeout() {
        let terminalExporter = ReentrantFlushExporter()
        let exporter = SpanInterceptorExporter(
            with: nil,
            proxy: SplunkStdoutSpanExporter(with: terminalExporter)
        )
        let processor = OTLPBatchSpanProcessor(
            spanExporter: exporter,
            scheduleDelay: Self.neverFires,
            maxExportBatchSize: Self.hugeBatch,
            maxQueueSize: 2_048
        )
        terminalExporter.onFirstExport = {
            processor.forceFlush()
        }
        let tracer = makeTracer(for: processor)

        endSpans(0 ..< 1, using: tracer)
        processor.forceFlush(timeout: 5)

        let timeout = terminalExporter.firstExportTimeout
        #expect(timeout != nil)
        #expect((timeout ?? 0) > 0)
        #expect((timeout ?? 0) <= 5)
        #expect(terminalExporter.successfulSpanCount == 1)
        #expect(terminalExporter.exportAttemptCount == 1)
    }


    // MARK: - Shutdown

    @Test
    func shutdownFromBackgroundQueueReturnsWithinBoundWhenExporterBlocks() {
        let exporter = FirstExportBlockingExporter()
        let processor = OTLPBatchSpanProcessor(
            spanExporter: exporter,
            scheduleDelay: Self.neverFires,
            maxExportBatchSize: 100,
            maxQueueSize: 2_048
        )
        let tracer = makeTracer(for: processor)

        endSpans(0 ..< 100, using: tracer)

        let completed = DispatchSemaphore(value: 0)
        let durationQueue = DispatchQueue(label: "com.splunk.batch-processor-test.duration")
        var shutdownDuration: TimeInterval?
        let start = Date()

        DispatchQueue.global(qos: .utility).async {
            processor.shutdown()
            durationQueue.sync {
                shutdownDuration = Date().timeIntervalSince(start)
            }
            completed.signal()
        }

        #expect(exporter.waitUntilFirstExportStarts(timeout: 5) == .success)
        #expect(completed.wait(timeout: .now() + 1.5) == .success)

        let elapsed = durationQueue.sync {
            shutdownDuration ?? .infinity
        }
        #expect(elapsed < 1.5)

        exporter.releaseFirstExport()
    }


    // MARK: - Partial requeue

    @Test
    func failedBatchPartiallyRequeuesWhenQueueHasLimitedSpace() {
        let exporter = FirstExportBlockingResultExporter(firstResult: .failure)
        let processor = OTLPBatchSpanProcessor(
            spanExporter: exporter,
            scheduleDelay: Self.neverFires,
            maxExportBatchSize: 100,
            maxQueueSize: 150
        )
        let tracer = makeTracer(for: processor)

        endSpans(0 ..< 100, using: tracer)
        #expect(exporter.waitUntilFirstExportStarts(timeout: 5) == .success)

        // Fill most of the queue while the failed batch is out for export. Only 25 slots remain for
        // requeue, so the processor should preserve span-0...span-24 instead of dropping all 100.
        endSpans(100 ..< 225, using: tracer)
        exporter.releaseFirstExport()
        #expect(exporter.waitForExport(timeout: 5) == .success)

        processor.forceFlush()

        #expect(exporter.successfulSpanCount == 150)
        #expect(exporter.successfulSpanNames.contains("span-0"))
        #expect(exporter.successfulSpanNames.contains("span-24"))
        #expect(!exporter.successfulSpanNames.contains("span-25"))
        #expect(exporter.successfulSpanNames.contains("span-224"))
    }

    @Test
    func persistentFailureIsNotReattemptedWithinOneDrain() {
        let exporter = BatchProcessorTestExporter(results: Array(repeating: .failure, count: 10))
        let core = BatchSpanProcessorCore(
            spanExporter: exporter,
            scheduleDelay: Self.neverFires,
            maxExportBatchSize: 100,
            maxQueueSize: 2_048
        )
        core.timer?.cancel()

        let tracer =
            TracerProviderBuilder()
            .build()
            .get(instrumentationName: "batch-safety-test", instrumentationVersion: "1.0")

        for index in 0 ..< 300 {
            let span = tracer.spanBuilder(spanName: "span-\(index)").startSpan()
            span.end()
            if let readable = span as? ReadableSpan {
                _ = core.queue.append(readable)
            }
        }

        core.drainSnapshot(deadline: nil, requeueOnFailure: true)

        #expect(exporter.exportAttemptCount == 1)
        #expect(exporter.successfulSpanCount == 0)
        #expect(core.queue.count == 300)
    }
}


// MARK: - Helpers

extension OTLPBatchProcessorSafetyTests {
    private static let neverFires: TimeInterval = 3_600
    private static let hugeBatch = 1_000_000

    private func makeTracer(for processor: OTLPBatchSpanProcessor) -> Tracer {
        TracerProviderTestBuilder
            .buildBatch(processor: processor)
            .get(instrumentationName: "batch-safety-test", instrumentationVersion: "1.0")
    }

    private func endSpans(_ range: Range<Int>, using tracer: Tracer) {
        for index in range {
            tracer.spanBuilder(spanName: "span-\(index)").startSpan().end()
        }
    }
}


private final class ReentrantFlushExporter: SpanExporter {
    private let lock = NSLock()
    private var storedExportAttemptCount = 0
    private var storedSuccessfulSpanCount = 0
    private var storedExportTimeouts: [TimeInterval?] = []

    var onFirstExport: (() -> Void)?

    var exportAttemptCount: Int {
        withLock { storedExportAttemptCount }
    }

    var successfulSpanCount: Int {
        withLock { storedSuccessfulSpanCount }
    }

    var firstExportTimeout: TimeInterval? {
        withLock { storedExportTimeouts.compactMap(\.self).first }
    }

    func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        let shouldReenter = withLock {
            storedExportAttemptCount += 1
            storedExportTimeouts.append(explicitTimeout)
            return storedExportAttemptCount == 1
        }

        if shouldReenter {
            onFirstExport?()
        }

        withLock {
            storedSuccessfulSpanCount += spans.count
        }
        return .success
    }

    func flush(explicitTimeout _: TimeInterval?) -> SpanExporterResultCode {
        .success
    }

    func shutdown(explicitTimeout _: TimeInterval?) {}

    private func withLock<T>(_ work: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try work()
    }
}


private final class FirstExportBlockingResultExporter: SpanExporter {
    private let lock = NSLock()
    private let started = DispatchSemaphore(value: 0)
    private let completed = DispatchSemaphore(value: 0)
    private let release = DispatchSemaphore(value: 0)
    private let firstResult: SpanExporterResultCode

    private var isFirstExport = true
    private var storedSuccessfulSpanNames: [String] = []

    init(firstResult: SpanExporterResultCode) {
        self.firstResult = firstResult
    }

    var successfulSpanNames: [String] {
        withLock { storedSuccessfulSpanNames }
    }

    var successfulSpanCount: Int {
        withLock { storedSuccessfulSpanNames.count }
    }

    func export(spans: [SpanData], explicitTimeout _: TimeInterval?) -> SpanExporterResultCode {
        lock.lock()
        let shouldBlock = isFirstExport
        isFirstExport = false
        lock.unlock()

        if shouldBlock {
            started.signal()
            release.wait()
            completed.signal()
            return firstResult
        }

        withLock {
            storedSuccessfulSpanNames.append(contentsOf: spans.map(\.name))
        }
        completed.signal()
        return .success
    }

    func flush(explicitTimeout _: TimeInterval?) -> SpanExporterResultCode {
        .success
    }

    func shutdown(explicitTimeout _: TimeInterval?) {}

    func waitUntilFirstExportStarts(timeout: TimeInterval) -> DispatchTimeoutResult {
        started.wait(timeout: .now() + timeout)
    }

    func waitForExport(timeout: TimeInterval) -> DispatchTimeoutResult {
        completed.wait(timeout: .now() + timeout)
    }

    func releaseFirstExport() {
        release.signal()
    }

    private func withLock<T>(_ work: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try work()
    }
}
