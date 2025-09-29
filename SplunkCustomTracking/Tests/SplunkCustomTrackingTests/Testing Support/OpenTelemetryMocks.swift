//
/*
Copyright 2025 Splunk Inc.

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

// MARK: - MockTracerProvider

class MockTracerProvider: TracerProvider {
    let mockTracer = MockTracer()

    func get(instrumentationName _: String, instrumentationVersion _: String?) -> OpenTelemetryApi.Tracer {
        mockTracer
    }

    /// Required for full protocol conformance
    func get(
        instrumentationName _: String,
        instrumentationVersion _: String?,
        schemaUrl _: String?,
        attributes _: [String: OpenTelemetryApi.AttributeValue]?
    ) -> OpenTelemetryApi.Tracer {
        mockTracer
    }
}

// MARK: - MockTracer

class MockTracer: Tracer {
    func spanBuilder(spanName: String) -> SpanBuilder {
        MockSpanBuilder(spanName: spanName)
    }
}

// MARK: - MockSpanBuilder

class MockSpanBuilder: SpanBuilder {
    let spanName: String
    var attributes: [String: AttributeValue] = [:]

    init(spanName: String) {
        self.spanName = spanName
    }

    func setParent(_: Span) -> Self { self }
    func setParent(_: SpanContext) -> Self { self }
    func setNoParent() -> Self { self }
    func addLink(spanContext _: SpanContext) -> Self { self }
    func addLink(spanContext _: SpanContext, attributes _: [String: AttributeValue]) -> Self { self }
    func setSpanKind(spanKind _: SpanKind) -> Self { self }
    func setStartTime(time _: Date) -> Self { self }
    func setAttribute(key: String, value: AttributeValue) -> Self {
        attributes[key] = value
        return self
    }

    // Required for full protocol conformance
    func setActive(_: Bool) -> Self { self }
    func withActiveSpan<T>(_ operation: (any SpanBase) throws -> T) rethrows -> T {
        let span = startSpan()
        return try operation(span)
    }

    func withActiveSpan<T>(_ operation: (any SpanBase) async throws -> T) async rethrows -> T {
        let span = startSpan()
        return try await operation(span)
    }

    func startSpan() -> Span {
        let span = MockSpan(name: spanName)
        span.attributes = attributes
        return span
    }
}

// MARK: - MockSpan (The "Readable" Span)

class MockSpan: Span {
    var name: String
    var kind: SpanKind = .internal
    var context: SpanContext
    var status: Status = .unset
    var isRecording: Bool = true
    var startTime = Date()
    var endTime: Date?

    var attributes: [String: AttributeValue] = [:]

    init(name: String) {
        self.name = name
        context = SpanContext.create(
            traceId: TraceId.random(),
            spanId: SpanId.random(),
            traceFlags: TraceFlags(),
            traceState: TraceState()
        )
    }

    func setAttribute(key: String, value: AttributeValue?) {
        guard let value else {
            return
        }

        attributes[key] = value
    }

    /// Required for full protocol conformance
    func setAttributes(_ attributes: [String: AttributeValue]) {
        for (key, value) in attributes {
            self.attributes[key] = value
        }
    }

    func recordException(_: any SpanException) {}
    func recordException(_: any SpanException, attributes _: [String: AttributeValue]) {}
    func recordException(_: any SpanException, timestamp _: Date) {}
    func recordException(_: any SpanException, attributes _: [String: AttributeValue], timestamp _: Date) {}

    func addEvent(name _: String, attributes _: [String: AttributeValue]) {}
    func addEvent(name _: String) {}
    func addEvent(name _: String, timestamp _: Date) {}
    func addEvent(name _: String, attributes _: [String: AttributeValue], timestamp _: Date) {}

    func end() {
        end(time: Date())
    }

    func end(time: Date) {
        isRecording = false
        endTime = time
    }

    var description: String {
        "MockSpan"
    }
}
