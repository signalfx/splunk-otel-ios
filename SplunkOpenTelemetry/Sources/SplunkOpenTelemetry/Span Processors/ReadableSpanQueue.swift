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

import OpenTelemetrySdk

/// Fixed-capacity FIFO storage that avoids shifting retained spans while producers hold the state lock.
struct ReadableSpanQueue {
    private var storage: [ReadableSpan?]
    private var head = 0
    private var tail = 0

    private(set) var count = 0

    init(capacity: Int) {
        storage = [ReadableSpan?](repeating: nil, count: capacity)
    }

    var isEmpty: Bool {
        count < 1
    }

    mutating func append(_ span: ReadableSpan) -> Bool {
        guard count < storage.count else {
            return false
        }

        storage[tail] = span
        tail = (tail + 1) % storage.count
        count += 1
        return true
    }

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

    private mutating func resetIndicesWhenEmpty() {
        guard isEmpty else {
            return
        }

        head = 0
        tail = 0
    }
}
