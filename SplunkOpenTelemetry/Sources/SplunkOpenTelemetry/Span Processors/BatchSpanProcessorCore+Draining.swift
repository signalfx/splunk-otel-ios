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
        timer.schedule(deadline: .now() + scheduleDelay, repeating: scheduleDelay)
        timer.setEventHandler { [weak self] in
            self?.exportCurrentBatch(retryOnFailure: true)
        }
        timer.resume()
        self.timer = timer
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
        lock.lock()
        isFlushScheduled = false
        let available = queue.count
        lock.unlock()

        var batchesToExport = available / maxExportBatchSize
        while batchesToExport > 0 {
            // Stop as soon as a batch fails (or the queue drains): on a persistently failing exporter
            // the failed batch is re-queued at the front, so continuing would just re-export the same
            // batch every iteration. The timer / next scheduled flush retries later instead.
            if !exportCurrentBatch(retryOnFailure: true) {
                break
            }
            batchesToExport -= 1
        }
    }


    // MARK: - Export

    /// Exports at most one batch; must be called on `processorQueue`.
    ///
    /// - Parameter retryOnFailure: When `true`, a failed export is re-queued (best effort) for a later attempt.
    /// - Returns: `true` if a batch was exported successfully; `false` if the queue was empty or the
    ///   export failed. Callers that loop should stop on `false` to avoid re-attempting a re-queued batch.
    @discardableResult
    private func exportCurrentBatch(retryOnFailure: Bool) -> Bool {
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

        let result = spanExporter.export(spans: batch.map { $0.toSpanData() })
        if result != .failure {
            return true
        }

        guard retryOnFailure else {
            return false
        }

        lock.lock()
        let requeued = queue.prepend(contentsOf: batch)
        lock.unlock()

        if !requeued {
            recordDroppedSpans(batch.count, reason: "export failed and queue full")
        }
        return false
    }

    /// Drains every buffered span in batch-sized chunks; must be called on `processorQueue`.
    ///
    /// Used on shutdown, where `isShutdown` has already stopped new spans from being enqueued, so the
    /// loop is guaranteed to terminate. Failures here are dropped (not re-queued) to guarantee
    /// termination; drops are accounted for and logged (throttled) via ``recordDroppedSpans(_:reason:)``.
    func drainAll() {
        while true {
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

            let result = spanExporter.export(spans: batch.map { $0.toSpanData() })
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
    func drainSnapshot(deadline: Date?, requeueOnFailure: Bool) {
        lock.lock()
        var remaining = queue.count
        lock.unlock()

        while remaining > 0 {
            if let deadline, Date() >= deadline {
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

            let result = spanExporter.export(spans: batch.map { $0.toSpanData() })

            if result == .failure {
                if requeueOnFailure {
                    // Best effort: put the batch back and stop, rather than re-exporting the same
                    // failing batch within this bounded drain. The timer / next flush will retry.
                    lock.lock()
                    let requeued = queue.prepend(contentsOf: batch)
                    lock.unlock()

                    if !requeued {
                        recordDroppedSpans(batch.count, reason: "export failed and queue full during drain")
                    }
                    break
                }

                recordDroppedSpans(batch.count, reason: "export failed during drain")
            }

            remaining -= batch.count
        }
    }


    // MARK: - Lifecycle

    func registerLifecycleObservers() {
        #if os(iOS) || os(tvOS) || os(visionOS)
            let backgroundToken = NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in
                // The app stays alive in the background, so favor host-app responsiveness: drain
                // asynchronously off the (main) notification thread. A snapshot drain keeps it bounded,
                // and failed exports are requeued (best effort) rather than dropped.
                self?.processorQueue
                    .async {
                        self?.drainSnapshot(deadline: nil, requeueOnFailure: true)
                    }
            }
            notificationObservers.append(backgroundToken)

            let terminateToken = NotificationCenter.default.addObserver(
                forName: UIApplication.willTerminateNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in
                // The process is about to die, so async work would be discarded before it runs. Drain
                // synchronously here: UI responsiveness no longer matters, but persisting the buffer
                // does. A bounded deadline prevents overrunning the termination window.
                self?.flushBeforeTermination()
            }
            notificationObservers.append(terminateToken)
        #endif
    }

    /// Drains the buffer when the app is terminating, blocking the caller only up to a wall-clock bound.
    ///
    /// The drain runs on `processorQueue` (so it cannot deadlock behind an in-flight export), while the
    /// caller waits on a semaphore capped at ``terminateFlushTimeout``. If the drain outlives that
    /// window it continues best effort on the queue, but we stop waiting so the OS watchdog can never
    /// kill the app because we blocked termination too long. Spans are dropped (not requeued) on
    /// failure here, since the process is going away and there is no later attempt.
    private func flushBeforeTermination() {
        let deadline = Date().addingTimeInterval(Self.terminateFlushTimeout)
        let completed = DispatchSemaphore(value: 0)

        processorQueue.async {
            self.drainSnapshot(deadline: deadline, requeueOnFailure: false)
            completed.signal()
        }

        _ = completed.wait(timeout: .now() + Self.terminateFlushTimeout)
    }

    func removeLifecycleObservers() {
        let tokens = notificationObservers
        notificationObservers.removeAll()

        for token in tokens {
            NotificationCenter.default.removeObserver(token)
        }
    }
}
