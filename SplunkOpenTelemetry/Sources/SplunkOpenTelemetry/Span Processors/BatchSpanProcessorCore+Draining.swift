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
import OpenTelemetrySdk

#if os(iOS) || os(tvOS) || os(visionOS)
    import UIKit
#endif

/// Draining, export, and lifecycle work for ``BatchSpanProcessorCore``.
///
/// Split into its own file to keep both the file length and the primary type body within the
/// project's SwiftLint limits. The members the core exposes to this extension are `internal`
/// (not `private`) for that reason; everything remains module-internal.
extension BatchSpanProcessorCore {

    // MARK: - Timer

    func startTimer() {
        let timer = DispatchSource.makeTimerSource(queue: processorQueue)
        timer.schedule(deadline: .distantFuture)
        timer.setEventHandler { [weak self] in
            self?.timerDidFire()
        }
        timer.resume()
        self.timer = timer
    }

    /// Arms the dormant one-shot timer when the first span enters an empty queue.
    func armTimerIfNeeded() {
        lock.lock()
        guard !isShutdown, !isTimerArmed, !queue.isEmpty else {
            lock.unlock()
            return
        }

        isTimerArmed = true
        lock.unlock()

        processorQueue.async { [weak self] in
            self?.scheduleArmedTimer()
        }
    }

    private func scheduleArmedTimer() {
        lock.lock()
        let shouldArm = !isShutdown && isTimerArmed && !queue.isEmpty
        if !shouldArm {
            isTimerArmed = false
        }
        lock.unlock()

        timer?.schedule(deadline: shouldArm ? .now() + scheduleDelay : .distantFuture)
    }

    private func timerDidFire() {
        lock.lock()
        isTimerArmed = false
        lock.unlock()

        exportCurrentBatch(retryOnFailure: true, explicitTimeout: nil)
        refreshTimerAfterDrain()
    }

    /// Rearms the one-shot timer only when a drain leaves spans queued.
    private func refreshTimerAfterDrain() {
        lock.lock()
        let shouldArm = !isShutdown && !queue.isEmpty
        isTimerArmed = shouldArm
        lock.unlock()

        timer?.schedule(deadline: shouldArm ? .now() + scheduleDelay : .distantFuture)
    }


    // MARK: - Flush scheduling

    /// Schedules a single coalesced drain on `processorQueue`.
    ///
    /// If a drain is already pending, this is a no-op, so a burst of over-threshold spans enqueues at
    /// most one drain closure instead of one per span.
    func scheduleFlush() {
        lock.lock()
        if isFlushScheduled {
            lock.unlock()
            return
        }
        isFlushScheduled = true
        lock.unlock()

        processorQueue.async { [weak self] in
            self?.performScheduledFlush()
        }
    }

    /// Drains the full batches that had accumulated when this coalesced flush was scheduled.
    ///
    /// The count is snapshotted so the drain is bounded; spans that arrive afterward re-arm the flag.
    /// Must run on `processorQueue`.
    private func performScheduledFlush() {
        defer { refreshTimerAfterDrain() }

        lock.lock()
        isFlushScheduled = false
        let available = queue.count
        lock.unlock()

        var batchesToExport = available / maxExportBatchSize
        while batchesToExport > 0 {
            // Stop as soon as a batch fails (or the queue drains): on a persistently failing exporter
            // the failed batch is re-queued at the front, so continuing would just re-export the same
            // batch every iteration. The timer / next scheduled flush retries later instead.
            if !exportCurrentBatch(retryOnFailure: true, explicitTimeout: nil) {
                break
            }
            batchesToExport -= 1
        }
    }


    // MARK: - Export

    /// Exports at most one batch; must be called on `processorQueue`.
    ///
    /// - Parameters:
    ///   - retryOnFailure: When `true`, a failed export is re-queued (best effort) for a later attempt.
    ///   - explicitTimeout: Optional timeout budget to forward to the exporter.
    /// - Returns: `true` if a batch was exported successfully; `false` if the queue was empty or the
    ///   export failed. Callers that loop should stop on `false` to avoid re-attempting a re-queued batch.
    @discardableResult
    private func exportCurrentBatch(retryOnFailure: Bool, explicitTimeout: TimeInterval?) -> Bool {
        lock.lock()
        if queue.isEmpty {
            lock.unlock()
            return false
        }
        let batch = queue.removeFirst(maxExportBatchSize)
        lock.unlock()

        guard !batch.isEmpty else {
            return false
        }

        let result = spanExporter.export(spans: batch.map { $0.toSpanData() }, explicitTimeout: explicitTimeout)
        if result != .failure {
            return true
        }

        guard retryOnFailure else {
            return false
        }

        requeueFailedBatch(batch, reason: "export failed and queue full")
        return false
    }

    /// Drains every buffered span in batch-sized chunks, optionally stopping at `deadline`; must be called on `processorQueue`.
    ///
    /// Used on shutdown, where `isShutdown` has already stopped new spans from being enqueued, so the
    /// loop is guaranteed to terminate. Failures are dropped (not re-queued) to guarantee termination;
    /// spans left after a non-nil deadline are also dropped. Drops are accounted for and logged via
    /// ``recordDroppedSpans(_:reason:)``.
    func drainAll(deadline: Date?) {
        defer { refreshTimerAfterDrain() }

        while true {
            if let deadline, Date() >= deadline {
                dropRemainingSpans(reason: "shutdown drain deadline exceeded")
                break
            }

            lock.lock()
            if queue.isEmpty {
                lock.unlock()
                break
            }
            let batch = queue.removeFirst(maxExportBatchSize)
            lock.unlock()

            guard !batch.isEmpty else {
                break
            }

            let result = spanExporter.export(
                spans: batch.map { $0.toSpanData() },
                explicitTimeout: nil
            )
            if result == .failure {
                recordDroppedSpans(batch.count, reason: "export failed during shutdown drain")
            }
        }
    }

    /// Drains only the spans present at entry, optionally stopping at `deadline`; must run on `processorQueue`.
    ///
    /// Bounded by the snapshotted count so concurrent producers cannot starve the caller.
    ///
    /// - Parameters:
    ///   - deadline: Optional wall-clock cutoff, checked between batches.
    ///   - requeueOnFailure: When `true` (background/`forceFlush`), a failed export is put back at the
    ///     front for a later attempt (timer / next flush) and the drain stops, so a transient disk
    ///     error does not permanently lose spans. When `false` (shutdown/terminate), a failed export is
    ///     dropped and the drain continues, so termination is guaranteed within the deadline.
    ///   - forwardDeadlineToExporter: When `true`, the remaining deadline is forwarded to the exporter.
    ///     Terminal drains keep this `false`, so their wall-clock wait bound does not become the
    ///     persisted background upload timeout.
    /// - Returns: `true` when the complete snapshot was drained; otherwise, `false` when the deadline
    ///   expired or an export failed and was requeued.
    @discardableResult
    func drainSnapshot(
        deadline: Date?,
        requeueOnFailure: Bool,
        forwardDeadlineToExporter: Bool = true
    ) -> Bool {
        defer { refreshTimerAfterDrain() }

        lock.lock()
        var remaining = queue.count
        lock.unlock()

        while remaining > 0 {
            if let deadline, Date() >= deadline {
                return false
            }

            lock.lock()
            if queue.isEmpty {
                lock.unlock()
                return false
            }
            let batch = queue.removeFirst(min(maxExportBatchSize, remaining))
            lock.unlock()

            guard !batch.isEmpty else {
                return false
            }

            let result = spanExporter.export(
                spans: batch.map { $0.toSpanData() },
                explicitTimeout: forwardDeadlineToExporter ? remainingTimeout(until: deadline) : nil
            )

            if result == .failure {
                if requeueOnFailure {
                    // Best effort: put the batch back and stop, rather than re-exporting the same
                    // failing batch within this bounded drain. The timer / next flush will retry.
                    requeueFailedBatch(batch, reason: "export failed and queue full during drain")
                    return false
                }

                recordDroppedSpans(batch.count, reason: "export failed during drain")
            }

            remaining -= batch.count
        }

        return true
    }

    private func requeueFailedBatch(_ batch: [ReadableSpan], reason: String) {
        lock.lock()
        let requeuedCount = queue.prependAsMuchAsPossible(contentsOf: batch)
        lock.unlock()

        let droppedCount = batch.count - requeuedCount
        if droppedCount > 0 {
            recordDroppedSpans(droppedCount, reason: reason)
        }
    }

    private func dropRemainingSpans(reason: String) {
        lock.lock()
        let remainingCount = queue.count
        _ = queue.removeFirst(remainingCount)
        lock.unlock()

        recordDroppedSpans(remainingCount, reason: reason)
    }

    private func remainingTimeout(until deadline: Date?) -> TimeInterval? {
        guard let deadline else {
            return nil
        }

        return max(0, deadline.timeIntervalSinceNow)
    }

    // MARK: - Lifecycle

    func registerBackgroundObserver(prepareForBackground: @escaping () async -> Void) {
        #if os(iOS) || os(tvOS) || os(visionOS)
            guard backgroundObserver == nil else {
                return
            }

            let backgroundToken = NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in
                self?.flushAfterBackgroundNotification(prepareForBackground: prepareForBackground)
            }
            backgroundObserver = backgroundToken
        #endif
    }

    private func flushAfterBackgroundNotification(prepareForBackground: @escaping () async -> Void) {
        // Defer one main-queue turn so later didEnterBackground observers can enqueue lifecycle spans
        // before this snapshot is taken. The app stays alive in the background, so keep the actual
        // drain asynchronous and off the notification thread.
        DispatchQueue.main.async { [weak self] in
            Task {
                await prepareForBackground()

                self?.processorQueue
                    .async {
                        self?.drainSnapshot(deadline: nil, requeueOnFailure: true)
                    }
            }
        }
    }

    func registerTerminationObserver(prepareForTermination: @escaping () async -> Void) {
        #if os(iOS) || os(tvOS) || os(visionOS)
            guard terminationObserver == nil else {
                return
            }

            let terminateToken = NotificationCenter.default.addObserver(
                forName: UIApplication.willTerminateNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in
                self?.flushBeforeTermination(prepareForTermination: prepareForTermination)
            }
            terminationObserver = terminateToken
        #endif
    }

    /// Drains the buffer when the app is terminating, blocking the caller only up to a wall-clock bound.
    ///
    /// Known terminal producers flush first, then the drain runs on `processorQueue` while the caller
    /// waits on a semaphore capped at ``terminateFlushTimeout``. If the work outlives that window it
    /// continues best effort, but we stop waiting so the OS watchdog can never kill the app because we
    /// blocked termination too long. Spans are dropped (not requeued) on export failure here, since the
    /// process is going away and there is no later attempt.
    private func flushBeforeTermination(prepareForTermination: @escaping () async -> Void) {
        let completed = DispatchSemaphore(value: 0)

        Task {
            await prepareForTermination()

            self.processorQueue.async {
                self.drainSnapshot(deadline: nil, requeueOnFailure: false, forwardDeadlineToExporter: false)
                completed.signal()
            }
        }

        _ = completed.wait(timeout: .now() + Self.terminateFlushTimeout)
    }

    func removeLifecycleObservers() {
        let tokens = [backgroundObserver, terminationObserver].compactMap(\.self)
        backgroundObserver = nil
        terminationObserver = nil

        for token in tokens {
            NotificationCenter.default.removeObserver(token)
        }
    }
}


extension OTLPBatchSpanProcessor {

    /// Registers the background drain that runs after asynchronous producers flush their spans.
    func registerBackgroundObserver(prepareForBackground: @escaping () async -> Void) {
        core.registerBackgroundObserver(prepareForBackground: prepareForBackground)
    }

    /// Registers the terminal lifecycle drain that runs after terminal producers flush their spans.
    func registerTerminationObserver(prepareForTermination: @escaping () async -> Void) {
        core.registerTerminationObserver(prepareForTermination: prepareForTermination)
    }
}
