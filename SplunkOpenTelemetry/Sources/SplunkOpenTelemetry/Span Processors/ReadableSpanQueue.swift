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

import OpenTelemetryApi
import OpenTelemetrySdk

/// A fixed-capacity, first-in-first-out queue for ended spans awaiting export.
///
/// The queue uses a ring buffer instead of removing elements from the beginning of an `Array`.
/// Removing the first array element shifts every retained element, extending the time producers
/// hold the batch processor's state lock. Advancing ring-buffer indices avoids that shift, keeps
/// append and single-element removal bookkeeping constant-time, and bounds memory use at the
/// configured capacity.
///
/// Spans removed for export can be prepended again if an export fails. Prepending preserves their
/// original order so retried spans remain ahead of spans added while the export was in progress.
struct ReadableSpanQueue {
    private var storage: [ReadableSpan?]
    private var head = 0
    private var tail = 0

    /// The number of spans currently stored in the queue.
    private(set) var count = 0

    /// The number of spans that can be added before the queue reaches its fixed capacity.
    var availableCapacity: Int {
        storage.count - count
    }

    /// Creates an empty queue with storage for the specified number of spans.
    ///
    /// - Parameter capacity: The maximum number of spans the queue can retain.
    init(capacity: Int) {
        storage = [ReadableSpan?](repeating: nil, count: capacity)
    }

    /// A Boolean value indicating whether the queue contains no spans.
    var isEmpty: Bool {
        count < 1
    }

    /// Adds a span to the end of the queue.
    ///
    /// - Parameter span: The span to enqueue.
    /// - Returns: `true` when the span was added, or `false` when the queue was already full.
    mutating func append(_ span: ReadableSpan) -> Bool {
        guard count < storage.count else {
            return false
        }

        storage[tail] = span
        tail = (tail + 1) % storage.count
        count += 1
        return true
    }

    /// Returns whether a span with the specified identifier is currently queued.
    func contains(spanId: SpanId) -> Bool {
        var index = head
        for _ in 0 ..< count {
            if storage[index]?.context.spanId == spanId {
                return true
            }
            index = (index + 1) % storage.count
        }
        return false
    }

    /// Removes up to the requested number of oldest spans.
    ///
    /// A negative request removes nothing, and a request larger than the current count removes all
    /// queued spans. Returned spans retain their FIFO order.
    ///
    /// - Parameter requestedCount: The maximum number of spans to remove.
    /// - Returns: The removed spans, ordered from oldest to newest.
    mutating func removeFirst(_ requestedCount: Int) -> [ReadableSpan] {
        let removalCount = min(max(0, requestedCount), count)
        var spans: [ReadableSpan] = []
        spans.reserveCapacity(removalCount)

        for _ in 0 ..< removalCount {
            if let span = storage[head] {
                spans.append(span)
            }
            storage[head] = nil
            head = (head + 1) % storage.count
        }

        count -= removalCount
        resetIndicesWhenEmpty()
        return spans
    }

    /// Adds a collection of spans ahead of all currently queued spans.
    ///
    /// The operation is all-or-nothing and preserves the order of both the prepended spans and the
    /// existing queue. It is used to restore an exported batch after a failed export attempt.
    ///
    /// - Parameter spans: The spans to restore at the front of the queue.
    /// - Returns: `true` when every span was prepended, or `false` when capacity was insufficient.
    mutating func prepend(contentsOf spans: [ReadableSpan]) -> Bool {
        guard spans.count <= storage.count - count else {
            return false
        }

        for span in spans.reversed() {
            head = (head - 1 + storage.count) % storage.count
            storage[head] = span
            count += 1
        }
        return true
    }

    /// Adds as many spans as possible ahead of all currently queued spans.
    ///
    /// When capacity is insufficient, the earliest prefix of `spans` is retained. The prepended
    /// spans preserve their input order.
    ///
    /// - Parameter spans: The spans to restore at the front of the queue.
    /// - Returns: The number of spans successfully prepended.
    mutating func prependAsMuchAsPossible(contentsOf spans: [ReadableSpan]) -> Int {
        let spansToPrepend = min(spans.count, availableCapacity)
        guard spansToPrepend > 0 else {
            return 0
        }

        let prefix = spans.prefix(spansToPrepend)
        for span in prefix.reversed() {
            head = (head - 1 + storage.count) % storage.count
            storage[head] = span
            count += 1
        }
        return spansToPrepend
    }

    /// Restores canonical indices after the last queued span is removed.
    private mutating func resetIndicesWhenEmpty() {
        guard isEmpty else {
            return
        }

        head = 0
        tail = 0
    }
}
