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

import OpenTelemetryApi
import OpenTelemetrySdk
import URLSessionInstrumentation
import XCTest

@testable import SplunkNetwork

final class SplunkNetworkTests: XCTestCase {
    private var sut: NetworkInstrumentation?
    
    /// Mock IgnoreURLs.
    private class MockIgnoreURLs: IgnoreURLs {
        var shouldMatch = false
        
        override func matches(url _: URL) -> Bool {
            shouldMatch
        }
    }
    
    /// Mock Span that conforms to all required protocols.
    private class MockSpan: Span {
        
        // MARK: - Public
        
        var attributes: [String: AttributeValue] = [:]
        var events: [SpanData.Event] = []
        var links: [SpanData.Link] = []
        var startTime = Date()
        var endTime: Date?
        var hasEnded: Bool = false
        var totalRecordedEvents: Int = 0
        var totalRecordedLinks: Int = 0
        var totalAttributeCount: Int = 0
        var parentSpanId: SpanId?
        var instrumentationScopeInfo = InstrumentationScopeInfo()


        // MARK: - SpanBase properties

        var kind: SpanKind { .internal }
        var context: SpanContext
        var isRecording: Bool { true }
        var status: Status = .unset
        var name: String = "MockSpan"


        // MARK: - Intialization

        init() {
            let traceId = TraceId.random()
            let spanId = SpanId.random()
            let traceFlags = TraceFlags()
            let traceState = TraceState()
            context = SpanContext.create(
                traceId: traceId,
                spanId: spanId,
                traceFlags: traceFlags,
                traceState: traceState
            )
        }


        // MARK: - Attributes

        func setAttribute(key: String, value: Any) {
            if let stringValue = value as? String {
                attributes[key] = .string(stringValue)
            }
            else if let intValue = value as? Int {
                attributes[key] = .int(intValue)
            }
            else if let doubleValue = value as? Double {
                attributes[key] = .double(doubleValue)
            }
            else if let boolValue = value as? Bool {
                attributes[key] = .bool(boolValue)
            }
        }


        // MARK: - SpanBase methods

        func setAttribute(key: String, value: AttributeValue?) {
            if let value {
                attributes[key] = value
            }
        }

        func setAttributes(_ attributes: [String: OpenTelemetryApi.AttributeValue]) {
            self.attributes = attributes
        }

        func addEvent(name _: String) {}
        func addEvent(name _: String, timestamp _: Date) {}
        func addEvent(name _: String, attributes _: [String: AttributeValue]) {}
        func addEvent(name _: String, attributes _: [String: AttributeValue], timestamp _: Date) {}


        // MARK: - Span methods

        func end() {}
        func end(time _: Date) {}


        // MARK: - SpanExceptionRecorder methods

        func recordException(_: SpanException) {}
        func recordException(_: SpanException, timestamp _: Date) {}
        func recordException(_: SpanException, attributes _: [String: AttributeValue]) {}
        func recordException(_: SpanException, attributes _: [String: AttributeValue], timestamp _: Date) {}

        // MARK: - CustomStringConvertible

        var description: String { "MockSpan" }
    }

    override func setUp() {
        super.setUp()

        sut = NetworkInstrumentation()
    }

    override func tearDown() {
        sut = nil

        super.tearDown()
    }
}
