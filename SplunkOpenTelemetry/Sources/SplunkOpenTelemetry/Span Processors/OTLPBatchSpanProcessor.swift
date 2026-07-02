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

    func sanitized() -> Self {
        let maxQueueSize = max(1, maxQueueSize)
        let maxExportBatchSize = min(max(1, maxExportBatchSize), maxQueueSize)

        return Self(
            scheduleDelay: max(0.001, scheduleDelay),
            wakeThreshold: min(max(1, wakeThreshold), maxQueueSize),
            maxQueueSize: maxQueueSize,
            maxExportBatchSize: maxExportBatchSize,
            exportTimeout: max(0, exportTimeout)
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

    private var pendingSpans: ReadableSpanQueue
    private var inFlightSpanCount = 0
    private var immediateDrainScheduled = false
    private var scheduledDelayedDrainGeneration: UInt64?
    private var nextDelayedDrainGeneration: UInt64 = 0
    private var isShutdown = false
    private var droppedSpansSinceLastReport = 0
    private var storedTotalDroppedSpans = 0


    // MARK: - Internal state

    var totalDroppedSpans: Int {
        withStateLock {
            storedTotalDroppedSpans
        }
    }

    var queuedSpanCount: Int {
        withStateLock {
            pendingSpans.count + inFlightSpanCount
        }
    }

    var isDelayedDrainScheduled: Bool {
        withStateLock {
            scheduledDelayedDrainGeneration != nil
        }
    }


    // MARK: - Initialization

    init(
        spanExporter: SpanExporter,
        configuration: TraceExportBatchConfiguration
    ) {
        let configuration = configuration.sanitized()
        self.spanExporter = spanExporter
        self.configuration = configuration
        pendingSpans = ReadableSpanQueue(capacity: configuration.maxQueueSize)
        exportQueue = DispatchQueue(
            label: PackageIdentifier.default(named: "batchSpanProcessor"),
            qos: .utility
        )
        exportQueue.setSpecific(key: exportQueueKey, value: ())
    }


    // MARK: - SpanProcessor

    func onStart(parentContext _: SpanContext?, span _: ReadableSpan) {}

    func onEnd(span: ReadableSpan) {
        guard span.context.traceFlags.sampled else {
            return
        }

        var shouldScheduleImmediateDrain = false
        var delayedDrainGeneration: UInt64?

        withStateLock {
            guard !isShutdown else {
                return
            }

            let retainedSpanCount = pendingSpans.count + inFlightSpanCount
            guard retainedSpanCount < configuration.maxQueueSize else {
                storedTotalDroppedSpans += 1
                droppedSpansSinceLastReport += 1
                return
            }

            let queueWasEmpty = pendingSpans.isEmpty
            guard pendingSpans.append(span) else {
                storedTotalDroppedSpans += 1
                droppedSpansSinceLastReport += 1
                return
            }

            if queueWasEmpty, scheduledDelayedDrainGeneration == nil {
                delayedDrainGeneration = reserveDelayedDrainGeneration()
            }

            if pendingSpans.count >= configuration.wakeThreshold,
                !immediateDrainScheduled
            {
                immediateDrainScheduled = true
                shouldScheduleImmediateDrain = true
            }
        }

        if let delayedDrainGeneration {
            scheduleDelayedDrain(generation: delayedDrainGeneration)
        }

        if shouldScheduleImmediateDrain {
            exportQueue.async { [weak self] in
                self?
                    .drainQueuedSpans(
                        includePartialBatch: false,
                        explicitTimeout: self?.configuration.exportTimeout
                    )
            }
        }
    }

    /// Persists the current in-memory batch without waiting for background URL session work.
    func persistPendingSpans(timeout: TimeInterval?) {
        performSynchronouslyOnExportQueue { [self] in
            drainQueuedSpans(includePartialBatch: true, explicitTimeout: timeout)
            reportDroppedSpansIfNeeded()
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
        let shouldShutdown = withStateLock {
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
            drainQueuedSpans(includePartialBatch: true, explicitTimeout: explicitTimeout)
            _ = spanExporter.flush(explicitTimeout: explicitTimeout)
            reportDroppedSpansIfNeeded()
            spanExporter.shutdown(explicitTimeout: explicitTimeout)
        }
    }


    // MARK: - Private methods

    private func reserveDelayedDrainGeneration() -> UInt64 {
        nextDelayedDrainGeneration &+= 1
        scheduledDelayedDrainGeneration = nextDelayedDrainGeneration
        return nextDelayedDrainGeneration
    }

    private func scheduleDelayedDrain(generation: UInt64) {
        exportQueue.asyncAfter(deadline: .now() + configuration.scheduleDelay) { [weak self] in
            guard let self else {
                return
            }

            guard claimDelayedDrain(generation: generation) else {
                return
            }

            drainQueuedSpans(
                includePartialBatch: true,
                explicitTimeout: configuration.exportTimeout
            )
            reportDroppedSpansIfNeeded()
        }
    }

    private func claimDelayedDrain(generation: UInt64) -> Bool {
        withStateLock {
            guard scheduledDelayedDrainGeneration == generation else {
                return false
            }

            scheduledDelayedDrainGeneration = nil
            return true
        }
    }

    private func drainQueuedSpans(
        includePartialBatch: Bool,
        explicitTimeout: TimeInterval?
    ) {
        let spans = withStateLock {
            immediateDrainScheduled = false

            if includePartialBatch {
                scheduledDelayedDrainGeneration = nil
            }

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

            let spans = pendingSpans.removeFirst(drainCount)
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

            withStateLock {
                inFlightSpanCount -= readableBatch.count
            }
            batchStart = batchEnd
        }
    }

    private func requeueAfterFailedExport(_ spans: [ReadableSpan]) {
        var delayedDrainGeneration: UInt64?

        withStateLock {
            let requeued = pendingSpans.prepend(contentsOf: spans)
            inFlightSpanCount -= spans.count

            guard requeued else {
                storedTotalDroppedSpans += spans.count
                droppedSpansSinceLastReport += spans.count
                return
            }

            if scheduledDelayedDrainGeneration == nil {
                delayedDrainGeneration = reserveDelayedDrainGeneration()
            }
        }

        if let delayedDrainGeneration {
            scheduleDelayedDrain(generation: delayedDrainGeneration)
        }
    }

    private func reportDroppedSpansIfNeeded() {
        let droppedSpans = withStateLock {
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

    private func withStateLock<T>(_ work: () throws -> T) rethrows -> T {
        stateLock.lock()
        defer { stateLock.unlock() }
        return try work()
    }
}
