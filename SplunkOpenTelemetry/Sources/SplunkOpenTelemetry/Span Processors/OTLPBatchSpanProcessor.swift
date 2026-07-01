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

internal import CiscoLogger
import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import SplunkCommon

struct TraceExportBatchConfiguration {
    let scheduleDelay: TimeInterval
    let wakeThreshold: Int
    let maxQueueSize: Int
    let maxExportBatchSize: Int
    let exportTimeout: TimeInterval

    static func production(exportTimeout: TimeInterval) -> Self {
        Self(
            scheduleDelay: 0.5,
            wakeThreshold: 100,
            maxQueueSize: 2_048,
            maxExportBatchSize: 100,
            exportTimeout: exportTimeout
        )
    }
}

/// Buffers ended spans in memory and exports them from a serial background queue.
///
/// The queue is intentionally bounded to protect the host application. Spans already accepted
/// by the processor remain accounted for while an export is in progress and are requeued if the
/// exporter reports a failure.
final class OTLPBatchSpanProcessor: SpanProcessor {

    // MARK: - SpanProcessor settings

    let isStartRequired = false
    let isEndRequired = true


    // MARK: - Private properties

    private let spanExporter: SpanExporter
    private let configuration: TraceExportBatchConfiguration
    private let stateLock = NSLock()
    private let exportQueue: DispatchQueue
    private let exportQueueKey = DispatchSpecificKey<Void>()
    private let logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "OpenTelemetry")

    private var timer: DispatchSourceTimer?
    private var pendingSpans: [ReadableSpan] = []
    private var inFlightSpanCount = 0
    private var immediateDrainScheduled = false
    private var isShutdown = false
    private var droppedSpansSinceLastReport = 0
    private var storedTotalDroppedSpans = 0


    // MARK: - Internal state

    var totalDroppedSpans: Int {
        stateLock.withLock {
            storedTotalDroppedSpans
        }
    }

    var queuedSpanCount: Int {
        stateLock.withLock {
            pendingSpans.count + inFlightSpanCount
        }
    }


    // MARK: - Initialization

    init(
        spanExporter: SpanExporter,
        configuration: TraceExportBatchConfiguration
    ) {
        self.spanExporter = spanExporter
        self.configuration = Self.sanitized(configuration)
        exportQueue = DispatchQueue(
            label: PackageIdentifier.default(named: "batchSpanProcessor"),
            qos: .utility
        )
        exportQueue.setSpecific(key: exportQueueKey, value: ())
        startTimer()
    }

    deinit {
        timer?.setEventHandler {}
        timer?.cancel()
    }


    // MARK: - SpanProcessor

    func onStart(parentContext _: SpanContext?, span _: ReadableSpan) {}

    func onEnd(span: ReadableSpan) {
        guard span.context.traceFlags.sampled else {
            return
        }

        var shouldScheduleDrain = false

        stateLock.withLock {
            guard !isShutdown else {
                return
            }

            let retainedSpanCount = pendingSpans.count + inFlightSpanCount
            guard retainedSpanCount < configuration.maxQueueSize else {
                storedTotalDroppedSpans += 1
                droppedSpansSinceLastReport += 1
                return
            }

            pendingSpans.append(span)

            if pendingSpans.count >= configuration.wakeThreshold,
                !immediateDrainScheduled
            {
                immediateDrainScheduled = true
                shouldScheduleDrain = true
            }
        }

        if shouldScheduleDrain {
            exportQueue.async { [weak self] in
                self?.drainQueuedSpans(
                    includePartialBatch: false,
                    explicitTimeout: self?.configuration.exportTimeout
                )
            }
        }
    }

    func forceFlush(timeout: TimeInterval?) {
        performSynchronouslyOnExportQueue { [self] in
            drainQueuedSpans(includePartialBatch: true, explicitTimeout: timeout)
            _ = spanExporter.flush(explicitTimeout: timeout)
            reportDroppedSpansIfNeeded()
        }
    }

    func shutdown(explicitTimeout: TimeInterval?) {
        let shouldShutdown = stateLock.withLock {
            guard !isShutdown else {
                return false
            }

            isShutdown = true
            return true
        }

        guard shouldShutdown else {
            return
        }

        performSynchronouslyOnExportQueue { [self] in
            timer?.setEventHandler {}
            timer?.cancel()
            timer = nil

            drainQueuedSpans(includePartialBatch: true, explicitTimeout: explicitTimeout)
            _ = spanExporter.flush(explicitTimeout: explicitTimeout)
            reportDroppedSpansIfNeeded()
            spanExporter.shutdown(explicitTimeout: explicitTimeout)
        }
    }


    // MARK: - Private methods

    private static func sanitized(_ configuration: TraceExportBatchConfiguration) -> TraceExportBatchConfiguration {
        let maxQueueSize = max(1, configuration.maxQueueSize)
        let maxExportBatchSize = min(max(1, configuration.maxExportBatchSize), maxQueueSize)

        return TraceExportBatchConfiguration(
            scheduleDelay: max(0.001, configuration.scheduleDelay),
            wakeThreshold: min(max(1, configuration.wakeThreshold), maxQueueSize),
            maxQueueSize: maxQueueSize,
            maxExportBatchSize: maxExportBatchSize,
            exportTimeout: max(0, configuration.exportTimeout)
        )
    }

    private func startTimer() {
        let timer = DispatchSource.makeTimerSource(queue: exportQueue)
        timer.schedule(
            deadline: .now() + configuration.scheduleDelay,
            repeating: configuration.scheduleDelay
        )
        timer.setEventHandler { [weak self] in
            guard let self else {
                return
            }

            drainQueuedSpans(
                includePartialBatch: true,
                explicitTimeout: configuration.exportTimeout
            )
            reportDroppedSpansIfNeeded()
        }
        timer.resume()
        self.timer = timer
    }

    private func drainQueuedSpans(
        includePartialBatch: Bool,
        explicitTimeout: TimeInterval?
    ) {
        let spans = stateLock.withLock {
            immediateDrainScheduled = false

            guard !pendingSpans.isEmpty else {
                return [ReadableSpan]()
            }

            let drainCount: Int
            if includePartialBatch {
                drainCount = pendingSpans.count
            }
            else {
                let completeBatchCount = pendingSpans.count / configuration.maxExportBatchSize
                drainCount = completeBatchCount * configuration.maxExportBatchSize
            }

            guard drainCount > 0 else {
                return [ReadableSpan]()
            }

            let spans = Array(pendingSpans.prefix(drainCount))
            pendingSpans.removeFirst(drainCount)
            inFlightSpanCount += spans.count
            return spans
        }

        guard !spans.isEmpty else {
            return
        }

        var batchStart = spans.startIndex

        while batchStart < spans.endIndex {
            let batchEnd = min(batchStart + configuration.maxExportBatchSize, spans.endIndex)
            let readableBatch = Array(spans[batchStart ..< batchEnd])
            let spanDataBatch = readableBatch.map { $0.toSpanData() }
            let result = spanExporter.export(
                spans: spanDataBatch,
                explicitTimeout: explicitTimeout
            )

            guard result == .success else {
                requeueAfterFailedExport(Array(spans[batchStart...]))
                return
            }

            stateLock.withLock {
                inFlightSpanCount -= readableBatch.count
            }
            batchStart = batchEnd
        }
    }

    private func requeueAfterFailedExport(_ spans: [ReadableSpan]) {
        stateLock.withLock {
            pendingSpans.insert(contentsOf: spans, at: pendingSpans.startIndex)
            inFlightSpanCount -= spans.count
        }
    }

    private func reportDroppedSpansIfNeeded() {
        let droppedSpans = stateLock.withLock {
            let droppedSpans = droppedSpansSinceLastReport
            droppedSpansSinceLastReport = 0
            return droppedSpans
        }

        guard droppedSpans > 0 else {
            return
        }

        logger.log(level: .warn, isPrivate: false) {
            "Dropped \(droppedSpans) spans because the in-memory trace export queue was full."
        }
    }

    private func performSynchronouslyOnExportQueue(_ work: () -> Void) {
        if DispatchQueue.getSpecific(key: exportQueueKey) != nil {
            work()
        }
        else {
            exportQueue.sync(execute: work)
        }
    }
}

private extension NSLock {
    func withLock<T>(_ work: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try work()
    }
}
