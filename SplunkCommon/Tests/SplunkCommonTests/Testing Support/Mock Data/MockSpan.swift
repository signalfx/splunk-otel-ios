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

/// Mock Span for use in tests.
class MockSpan: Span {

    // MARK: - Public

    var name: String
    var kind: SpanKind = .internal
    var context: SpanContext
    var status: Status = .unset
    var isRecording: Bool = true
    var startTime = Date()
    var endTime: Date?

    var attributes: [String: AttributeValue] = [:]


    // MARK: - Initialization

    init(name: String) {
        self.name = name
        context = SpanContext.create(
            traceId: TraceId.random(),
            spanId: SpanId.random(),
            traceFlags: TraceFlags(),
            traceState: TraceState()
        )
    }


    // MARK: - SpanBase mathods

    func setAttribute(key: String, value: AttributeValue?) {
        if let value {
            attributes[key] = value
        }
        else {
            attributes.removeValue(forKey: key)
        }
    }

    /// Method is required for full protocol conformance.
    func setAttributes(_ attributes: [String: AttributeValue]) {
        for (key, value) in attributes {
            self.attributes[key] = value
        }
    }

    func addEvent(name _: String, attributes _: [String: AttributeValue]) {}
    func addEvent(name _: String) {}
    func addEvent(name _: String, timestamp _: Date) {}
    func addEvent(name _: String, attributes _: [String: AttributeValue], timestamp _: Date) {}


    // MARK: - SpanExceptionRecorder methods

    func recordException(_: any SpanException) {}
    func recordException(_: any SpanException, attributes _: [String: AttributeValue]) {}
    func recordException(_: any SpanException, timestamp _: Date) {}
    func recordException(_: any SpanException, attributes _: [String: AttributeValue], timestamp _: Date) {}


    // MARK: - Span methods

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
