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
import XCTest

@testable import SplunkNetwork

final class SpanLinkingTests: XCTestCase {

    // MARK: - Mock Span

    private class MockSpan: Span {
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

        var kind: SpanKind { .internal }
        var context: SpanContext
        var isRecording: Bool { true }
        var status: Status = .unset
        var name: String = "MockSpan"

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

        func setAttribute(key: String, value: AttributeValue?) {
            if let value {
                attributes[key] = value
            }
        }

        func setAttributes(_ attributes: [String: AttributeValue]) {
            self.attributes = attributes
        }

        func addEvent(name _: String) {}
        func addEvent(name _: String, timestamp _: Date) {}
        func addEvent(name _: String, attributes _: [String: AttributeValue]) {}
        func addEvent(name _: String, attributes _: [String: AttributeValue], timestamp _: Date) {}

        func end() {
            hasEnded = true
        }

        func end(time: Date) {
            hasEnded = true
            endTime = time
        }

        func recordException(_: SpanException) {}
        func recordException(_: SpanException, timestamp _: Date) {}
        func recordException(_: SpanException, attributes _: [String: AttributeValue]) {}
        func recordException(_: SpanException, attributes _: [String: AttributeValue], timestamp _: Date) {}

        var description: String { "MockSpan" }
    }

    // MARK: - Tests

    func testAddLinkToSpan_ValidTraceParent() {
        let mockSpan = MockSpan()
        let valStr = "traceparent;desc='00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01'"

        addLinkToSpan(span: mockSpan, valStr: valStr)

        XCTAssertEqual(mockSpan.attributes["link.traceId"]?.description, "0af7651916cd43dd8448eb211c80319c")
        XCTAssertEqual(mockSpan.attributes["link.spanId"]?.description, "b7ad6b7169203331")
    }

    func testAddLinkToSpan_ValidTraceParent_DoubleQuotes() {
        let mockSpan = MockSpan()
        let valStr = #"traceparent;desc="00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01""#

        addLinkToSpan(span: mockSpan, valStr: valStr)

        XCTAssertEqual(mockSpan.attributes["link.traceId"]?.description, "0af7651916cd43dd8448eb211c80319c")
        XCTAssertEqual(mockSpan.attributes["link.spanId"]?.description, "b7ad6b7169203331")
    }

    func testAddLinkToSpan_InvalidTraceParent() {
        let mockSpan = MockSpan()
        let valStr = "traceparent;desc='invalid-trace-id'"

        addLinkToSpan(span: mockSpan, valStr: valStr)

        // Should not add attributes for invalid traceparent
        XCTAssertNil(mockSpan.attributes["link.traceId"])
        XCTAssertNil(mockSpan.attributes["link.spanId"])
    }

    func testAddLinkToSpan_EmptyString() {
        let mockSpan = MockSpan()
        let valStr = ""

        addLinkToSpan(span: mockSpan, valStr: valStr)

        XCTAssertNil(mockSpan.attributes["link.traceId"])
        XCTAssertNil(mockSpan.attributes["link.spanId"])
    }
}
