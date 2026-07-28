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

@Suite
struct ReadableSpanQueueTests {

    // MARK: - Helpers

    /// Produces `count` distinct `ReadableSpan`s named `s0`, `s1`, ... via a real SDK tracer.
    private func makeSpans(_ count: Int) -> [ReadableSpan] {
        let tracer = TracerProviderBuilder()
            .build()
            .get(instrumentationName: "queue-test", instrumentationVersion: "1.0")

        var spans: [ReadableSpan] = []
        for index in 0 ..< count {
            if let readable = tracer.spanBuilder(spanName: "s\(index)").startSpan() as? ReadableSpan {
                spans.append(readable)
            }
        }
        return spans
    }


    // MARK: - append

    @Test
    func appendFillsUpToCapacityThenRejects() {
        let spans = makeSpans(4)
        var queue = ReadableSpanQueue(capacity: 3)

        let appended = [queue.append(spans[0]), queue.append(spans[1]), queue.append(spans[2])]
        #expect(!appended.contains(false))
        #expect(queue.count == 3)

        // Queue is full: the newest span is rejected.
        let rejected = queue.append(spans[3])
        #expect(rejected == false)
        #expect(queue.count == 3)
    }


    // MARK: - removeFirst

    @Test
    func removeFirstReturnsSpansInFIFOOrder() {
        let spans = makeSpans(3)
        var queue = ReadableSpanQueue(capacity: 3)
        for span in spans {
            _ = queue.append(span)
        }

        let firstTwo = queue.removeFirst(2)
        #expect(firstTwo.map(\.name) == ["s0", "s1"])
        #expect(queue.count == 1)

        // Requesting more than remaining returns only what is left.
        let rest = queue.removeFirst(5)
        #expect(rest.map(\.name) == ["s2"])
        #expect(queue.isEmpty)
    }

    @Test
    func removeFirstOnEmptyQueueReturnsNothing() {
        var queue = ReadableSpanQueue(capacity: 3)
        let removed = queue.removeFirst(2)
        #expect(removed.isEmpty)
        #expect(queue.isEmpty)
    }


    // MARK: - prepend

    @Test
    func prependInsertsSpansAtFrontPreservingOrder() {
        let spans = makeSpans(3)
        var queue = ReadableSpanQueue(capacity: 3)
        _ = queue.append(spans[0])

        let prepended = queue.prepend(contentsOf: [spans[1], spans[2]])
        #expect(prepended)
        #expect(queue.count == 3)

        // Prepended spans keep their relative order and precede the existing span.
        let drained = queue.removeFirst(3)
        #expect(drained.map(\.name) == ["s1", "s2", "s0"])
    }

    @Test
    func prependRejectsWhenItWouldExceedCapacity() {
        let spans = makeSpans(4)
        var queue = ReadableSpanQueue(capacity: 3)
        _ = queue.append(spans[0])
        _ = queue.append(spans[1])

        let prepended = queue.prepend(contentsOf: [spans[2], spans[3]])
        #expect(prepended == false)
        #expect(queue.count == 2)
    }


    // MARK: - Index reset

    @Test
    func queueCanBeRefilledAfterBeingEmptied() {
        let first = makeSpans(3)
        var queue = ReadableSpanQueue(capacity: 3)
        for span in first {
            _ = queue.append(span)
        }
        _ = queue.removeFirst(3)
        #expect(queue.isEmpty)

        // After emptying, the queue must accept a full capacity again in correct order.
        let second = makeSpans(3)
        var refilled: [Bool] = []
        for span in second {
            refilled.append(queue.append(span))
        }
        #expect(!refilled.contains(false))
        #expect(queue.count == 3)

        let drained = queue.removeFirst(3)
        #expect(drained.map(\.name) == ["s0", "s1", "s2"])
    }
}
