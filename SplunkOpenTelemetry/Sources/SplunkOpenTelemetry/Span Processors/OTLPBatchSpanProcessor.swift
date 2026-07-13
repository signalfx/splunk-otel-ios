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

/// An in-memory batching span processor.
///
/// Instead of exporting one span per ended span (as `SimpleSpanProcessor` does), this processor
/// pools ended spans in a bounded in-memory queue and hands a batch to the exporter either when
/// the batch reaches ``Defaults/maxExportBatchSize`` spans or every ``Defaults/scheduleDelay``
/// seconds, whichever happens first. It also flushes on app background/terminate and on shutdown.
///
/// - Important: Spans that are still buffered in memory when the host app crashes are lost. This is
///   an accepted trade-off in exchange for fewer, larger disk writes on the export path.
struct OTLPBatchSpanProcessor: SpanProcessor {

    // MARK: - Defaults

    /// Default configuration values for the batching behavior.
    enum Defaults {

        /// Maximum number of spans in a single exported batch; reaching this count triggers an immediate flush.
        static let maxExportBatchSize = 100

        /// Interval between periodic flushes of the in-memory batch.
        static let scheduleDelay: TimeInterval = 0.5

        /// Maximum number of spans held in memory; spans arriving while the queue is full are dropped.
        static let maxQueueSize = 2_048
    }


    // MARK: - Private properties

    private let core: BatchSpanProcessorCore


    // MARK: - SpanProcessor settings

    let isStartRequired = false

    let isEndRequired = true


    // MARK: - Initialization

    /// Initializes a new in-memory batching span processor.
    ///
    /// - Parameters:
    ///   - spanExporter: The exporter that receives batches of spans.
    ///   - scheduleDelay: Interval between periodic flushes. Defaults to ``Defaults/scheduleDelay``.
    ///   - maxExportBatchSize: Batch size that triggers an immediate flush. Defaults to ``Defaults/maxExportBatchSize``.
    ///   - maxQueueSize: Maximum number of spans buffered in memory. Defaults to ``Defaults/maxQueueSize``.
    init(
        spanExporter: SpanExporter,
        scheduleDelay: TimeInterval = Defaults.scheduleDelay,
        maxExportBatchSize: Int = Defaults.maxExportBatchSize,
        maxQueueSize: Int = Defaults.maxQueueSize
    ) {
        core = BatchSpanProcessorCore(
            spanExporter: spanExporter,
            scheduleDelay: scheduleDelay,
            maxExportBatchSize: maxExportBatchSize,
            maxQueueSize: maxQueueSize
        )
    }


    // MARK: - SpanProcessor methods

    func onStart(parentContext _: SpanContext?, span _: ReadableSpan) {}

    func onEnd(span: ReadableSpan) {
        core.onEnd(span: span)
    }

    func shutdown(explicitTimeout: TimeInterval? = nil) {
        core.shutdown(explicitTimeout: explicitTimeout)
    }

    func forceFlush(timeout: TimeInterval? = nil) {
        core.forceFlush(timeout: timeout)
    }

    /// Registers the terminal lifecycle drain after modules have registered their own observers.
    func registerTerminationObserver() {
        core.registerTerminationObserver()
    }
}


/// Reference-type backing store for ``OTLPBatchSpanProcessor``.
///
/// `SpanProcessor` is a value type, but the batching state (queue, timer, lifecycle observers) is
/// inherently mutable and shared, so it lives in this class. Copies of the value-type processor
/// share a single core. The draining, export, and lifecycle logic lives in
/// `BatchSpanProcessorCore+Draining.swift`; state used by that extension is `internal` (not
/// `private`) for that reason, but the whole type remains module-internal.
final class BatchSpanProcessorCore {

    // MARK: - Constants

    /// Lower bound for the periodic flush interval, to avoid a zero/near-zero timer busy-looping the queue.
    private static let minimumScheduleDelay: TimeInterval = 0.1

    /// Hard wall-clock bound on how long termination is allowed to block the caller while draining.
    ///
    /// On `willTerminate` the process is being torn down, so we drain best effort but stop waiting
    /// after this window so we never risk the watchdog killing the app mid-drain.
    static let terminateFlushTimeout: TimeInterval = 2.0

    /// Hard wall-clock bound on how long `shutdown` blocks the caller while draining.
    ///
    /// Unlike `forceFlush`, shutdown is a one-shot teardown: after it the processor may be released,
    /// so the buffer's remaining drain has no guaranteed later chance. A short bounded wait improves
    /// final persistence without risking a host-app hang; on timeout the drain continues best effort.
    private static let shutdownWaitTimeout: TimeInterval = 1.0

    /// Minimum interval between dropped-span log emissions, so overflow bursts cannot flood the log.
    private static let dropLogInterval: TimeInterval = 5.0


    // MARK: - Properties

    let spanExporter: SpanExporter
    let scheduleDelay: TimeInterval
    let maxExportBatchSize: Int
    private let maxQueueSize: Int

    /// Serial queue that owns the periodic timer and serializes all export work.
    let processorQueue = DispatchQueue(
        label: PackageIdentifier.default(named: "BatchSpanProcessor"),
        qos: .utility
    )

    private let processorQueueKey = DispatchSpecificKey<Void>()

    /// Guards `queue`, `isShutdown`, `isFlushScheduled`, and the drop-tracking counters.
    let lock = NSLock()

    var queue: ReadableSpanQueue

    private var isShutdown = false

    /// Coalesces size-triggered flushes: at most one drain is pending on `processorQueue` at a time.
    var isFlushScheduled = false

    /// Cumulative number of spans dropped this session (overflow + failed exports); guarded by `lock`.
    private var droppedSpanCount = 0

    /// Spans dropped since the last emitted drop log, reset each time a log is emitted; guarded by `lock`.
    private var dropsSinceLastLog = 0

    /// Timestamp of the last emitted drop log, used to throttle logging; guarded by `lock`.
    private var lastDropLogAt: Date?

    var timer: DispatchSourceTimer?

    var backgroundObserver: NSObjectProtocol?

    var terminationObserver: NSObjectProtocol?

    /// Internal Logger.
    private let logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "OpenTelemetry")


    // MARK: - Initialization

    init(
        spanExporter: SpanExporter,
        scheduleDelay: TimeInterval,
        maxExportBatchSize: Int,
        maxQueueSize: Int
    ) {
        self.spanExporter = spanExporter
        self.scheduleDelay = max(Self.minimumScheduleDelay, scheduleDelay)
        self.maxExportBatchSize = max(1, maxExportBatchSize)
        // The queue must be able to hold at least one full batch.
        self.maxQueueSize = max(maxQueueSize, self.maxExportBatchSize)
        queue = ReadableSpanQueue(capacity: self.maxQueueSize)

        processorQueue.setSpecific(key: processorQueueKey, value: ())
        startTimer()
        registerBackgroundObserver()
    }

    deinit {
        timer?.cancel()
        removeLifecycleObservers()
    }


    // MARK: - SpanProcessor forwarding

    func onEnd(span: ReadableSpan) {
        // Match SimpleSpanProcessor: only report sampled spans.
        guard span.context.traceFlags.sampled else {
            return
        }

        lock.lock()
        if isShutdown {
            lock.unlock()
            return
        }
        let appended = queue.append(span)
        let count = queue.count
        lock.unlock()

        if !appended {
            recordDroppedSpans(1, reason: "queue full (capacity \(maxQueueSize))")
            return
        }

        if count >= maxExportBatchSize {
            scheduleFlush()
        }
    }

    func forceFlush(timeout: TimeInterval?) {
        // Bounded: drain only the spans present at entry, and stop once the (optional) deadline passes,
        // so a concurrent producer can never starve the caller.
        //
        // On the main thread this is intentionally fire-and-forget (no bounded wait). forceFlush is
        // non-terminal: the process keeps running, so any spans not drained "before return" are still
        // persisted a fraction of a second later by the same asynchronous drain. Blocking the main
        // thread would therefore add UI stall only to buy a "persisted-by-return" guarantee that has
        // no telemetry benefit while the app is alive. The cases where the synchronous window is the
        // *only* chance to persist (background/terminate/shutdown) are bounded-waited separately.
        let deadline = timeout.map { Date().addingTimeInterval($0) }
        runOnProcessorQueue(wait: nil) {
            self.drainSnapshot(deadline: deadline, requeueOnFailure: true)
            _ = self.spanExporter.flush(explicitTimeout: deadline.map { max(0, $0.timeIntervalSinceNow) })
        }
    }

    func shutdown(explicitTimeout: TimeInterval?) {
        lock.lock()
        if isShutdown {
            lock.unlock()
            return
        }
        isShutdown = true
        lock.unlock()

        timer?.cancel()
        timer = nil
        removeLifecycleObservers()

        // Block only up to `shutdownWaitTimeout`, regardless of calling thread. On timeout the
        // drain and exporter shutdown continue best effort on the queue (the closure retains `self`).
        let waitTimeout = shutdownWaitTimeout(for: explicitTimeout)
        let deadline = Date().addingTimeInterval(waitTimeout)
        runOnProcessorQueue(wait: waitTimeout) {
            self.drainAll(deadline: deadline)
            self.spanExporter.shutdown(explicitTimeout: explicitTimeout)
        }
    }


    // MARK: - Queue hop

    /// Runs export work on `processorQueue`, never hanging a caller unboundedly when a wait is supplied.
    ///
    /// - Parameters:
    ///   - wait: When `nil`, main-thread work is dispatched fire-and-forget and off-main work runs
    ///     synchronously. When set, every caller blocks up to this many seconds for the work to finish;
    ///     on timeout the work continues best effort on the queue.
    ///   - work: The export work to run on `processorQueue`.
    private func runOnProcessorQueue(wait: TimeInterval?, _ work: @escaping () -> Void) {
        if DispatchQueue.getSpecific(key: processorQueueKey) != nil {
            work()
            return
        }

        if let wait {
            // Bounded wait: init 0; whether `signal()` or the timeout wins, the semaphore's final value
            // is >= 0, so it is safe to let it deallocate after the closure is captured by the async block.
            let completed = DispatchSemaphore(value: 0)
            processorQueue.async {
                work()
                completed.signal()
            }
            _ = completed.wait(timeout: .now() + wait)
            return
        }

        guard Thread.isMainThread else {
            processorQueue.sync(execute: work)
            return
        }

        processorQueue.async(execute: work)
    }

    private func shutdownWaitTimeout(for explicitTimeout: TimeInterval?) -> TimeInterval {
        min(Self.shutdownWaitTimeout, max(0, explicitTimeout ?? Self.shutdownWaitTimeout))
    }


    // MARK: - Drop accounting

    /// Accounts for and logs dropped spans so high-throughput loss is observable instead of silent.
    ///
    /// Every drop path (in-memory overflow and failed exports) routes through here. The cumulative
    /// total is always updated, but logging is throttled to at most one line per ``dropLogInterval``
    /// so a sustained overflow burst (potentially thousands of drops/second) cannot flood the log and
    /// add I/O pressure while the app is already saturated. Each emitted line reports the number of
    /// spans dropped since the previous line plus the running session total.
    func recordDroppedSpans(_ spanCount: Int, reason: String) {
        guard spanCount > 0 else {
            return
        }

        lock.lock()
        droppedSpanCount += spanCount
        dropsSinceLastLog += spanCount
        let total = droppedSpanCount

        let now = Date()
        let shouldLog = lastDropLogAt.map { now.timeIntervalSince($0) >= Self.dropLogInterval } ?? true
        let delta = dropsSinceLastLog
        if shouldLog {
            lastDropLogAt = now
            dropsSinceLastLog = 0
        }
        lock.unlock()

        guard shouldLog else {
            return
        }

        logger.log(level: .error) {
            "Dropped \(delta) span(s) since last report (latest: \(reason)); total dropped this session: \(total)."
        }
    }
}
