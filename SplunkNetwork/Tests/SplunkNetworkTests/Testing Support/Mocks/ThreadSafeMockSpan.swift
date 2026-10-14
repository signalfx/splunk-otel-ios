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

final class ThreadSafeMockSpan: Span {
    struct RecordedEvent {
        let name: String
        let timestamp: Date
    }

    private let lock = NSLock()
    private var storedAttributes: [String: AttributeValue] = [:]
    private var storedEndCount = 0
    private var storedEndInvocationCount = 0
    private var storedEndTimes: [Date] = []
    private var storedEvents: [RecordedEvent] = []
    private var ended = false

    var attributes: [String: AttributeValue] {
        lock.lock()
        defer { lock.unlock() }
        return storedAttributes
    }

    var endCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedEndCount
    }

    var endInvocationCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedEndInvocationCount
    }

    var endTimes: [Date] {
        lock.lock()
        defer { lock.unlock() }
        return storedEndTimes
    }

    var events: [RecordedEvent] {
        lock.lock()
        defer { lock.unlock() }
        return storedEvents
    }

    let context = SpanContext.create(
        traceId: .random(),
        spanId: .random(),
        traceFlags: TraceFlags(),
        traceState: TraceState()
    )

    var isRecording: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !ended
    }

    var status: Status = .unset
    var name = "NetworkSpanFinalizationCoordinatorTests"
    var kind: SpanKind {
        .client
    }

    func setAttribute(key: String, value: AttributeValue?) {
        lock.lock()
        defer { lock.unlock() }
        guard !ended else {
            return
        }

        if let value {
            storedAttributes[key] = value
        }
        else {
            storedAttributes.removeValue(forKey: key)
        }
    }

    func setAttributes(_ attributes: [String: AttributeValue]) {
        for (key, value) in attributes {
            setAttribute(key: key, value: value)
        }
    }

    func addEvent(name _: String) {}

    func addEvent(name: String, timestamp: Date) {
        lock.lock()
        defer { lock.unlock() }
        guard !ended else {
            return
        }

        storedEvents.append(RecordedEvent(name: name, timestamp: timestamp))
    }

    func addEvent(name _: String, attributes _: [String: AttributeValue]) {}
    func addEvent(name _: String, attributes _: [String: AttributeValue], timestamp _: Date) {}

    func end() {
        recordEnd()
    }

    func end(time: Date) {
        recordEnd(time: time)
    }

    private func recordEnd(time: Date? = nil) {
        lock.lock()
        defer { lock.unlock() }
        storedEndInvocationCount += 1
        if let time {
            storedEndTimes.append(time)
        }

        guard !ended else {
            return
        }

        ended = true
        storedEndCount += 1
    }

    func recordException(_: SpanException) {}
    func recordException(_: SpanException, timestamp _: Date) {}
    func recordException(_: SpanException, attributes _: [String: AttributeValue]) {}
    func recordException(_: SpanException, attributes _: [String: AttributeValue], timestamp _: Date) {}

    var description: String {
        name
    }
}
