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

// A collection of local, high-quality test helpers for OpenTelemetry objects.
// These are designed to be easily moved to a shared test utility module later.

// MARK: - MockTracerProvider

class MockTracerProvider: TracerProvider {
    let mockTracer = MockTracer()

    func get(instrumentationName: String, instrumentationVersion: String?) -> OpenTelemetryApi.Tracer {
        return mockTracer
    }

    // Required for full protocol conformance
    func get(instrumentationName: String,
             instrumentationVersion: String?,
             schemaUrl: String?,
             attributes: [String: OpenTelemetryApi.AttributeValue]?) -> OpenTelemetryApi.Tracer {
        return mockTracer
    }
}

// MARK: - MockTracer

class MockTracer: Tracer {
    func spanBuilder(spanName: String) -> SpanBuilder {
        return MockSpanBuilder(spanName: spanName)
    }
}

// MARK: - MockSpanBuilder

class MockSpanBuilder: SpanBuilder {
    let spanName: String
    var attributes: [String: AttributeValue] = [:]

    init(spanName: String) {
        self.spanName = spanName
    }

    func setParent(_ parent: Span) -> Self { return self }
    func setParent(_ parentContext: SpanContext) -> Self { return self }
    func setNoParent() -> Self { return self }
    func addLink(spanContext: SpanContext) -> Self { return self }
    func addLink(spanContext: SpanContext, attributes: [String: AttributeValue]) -> Self { return self }
    func setSpanKind(spanKind: SpanKind) -> Self { return self }
    func setStartTime(time: Date) -> Self { return self }
    func setAttribute(key: String, value: AttributeValue) -> Self {
        attributes[key] = value
        return self
    }

    // Required for full protocol conformance
    func setActive(_ active: Bool) -> Self { return self }
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
        context = SpanContext.create(traceId: TraceId.random(),
                                     spanId: SpanId.random(),
                                     traceFlags: TraceFlags(),
                                     traceState: TraceState())
    }

    func setAttribute(key: String, value: AttributeValue?) {
        guard let value = value else { return }
        attributes[key] = value
    }

    // Required for full protocol conformance
    func setAttributes(_ attributes: [String: AttributeValue]) {
        for (key, value) in attributes {
            self.attributes[key] = value
        }
    }

    func recordException(_ exception: any SpanException) {}
    func recordException(_ exception: any SpanException, attributes: [String: AttributeValue]) {}
    func recordException(_ exception: any SpanException, timestamp: Date) {}
    func recordException(_ exception: any SpanException, attributes: [String: AttributeValue], timestamp: Date) {}

    func addEvent(name: String, attributes: [String: AttributeValue]) {}
    func addEvent(name: String) {}
    func addEvent(name: String, timestamp: Date) {}
    func addEvent(name: String, attributes: [String: AttributeValue], timestamp: Date) {}

    func end() {
        end(time: Date())
    }

    func end(time: Date) {
        isRecording = false
        endTime = time
    }

    var description: String {
        return "MockSpan"
    }
}
