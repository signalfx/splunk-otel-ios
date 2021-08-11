/*
Copyright 2021 Splunk Inc.

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
import XCTest
@testable import SplunkRum

class TestSpan: Span {
    var isRecording: Bool

    var status: Status

//    var scope: Scope?

    func end() {
    }

    func end(time: Date) {
    }

    public var attrs: [String: String]
    func setAttribute(key: String, value: AttributeValue?) {
        attrs.updateValue(value!.description, forKey: key)
    }

    public init() {
        attrs = Dictionary()
        kind = .internal
        isRecording = true
        name = "test"
        description = "test"
        context = OpenTelemetry.instance.contextProvider.activeSpan!.context
        status = .unset
    }
    var kind: SpanKind

    var context: SpanContext

    var name: String

    func addEvent(name: String) {
    }

    func addEvent(name: String, timestamp: Date) {
    }

    func addEvent(name: String, attributes: [String: AttributeValue]) {
    }

    func addEvent(name: String, attributes: [String: AttributeValue], timestamp: Date) {
    }

    var description: String

}

class ServerTimingTests: XCTestCase {

    func testBasicBehavior() throws {
        let span = TestSpan()
        addLinkToSpan(span: span, valStr: "traceparent;desc=\"00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01\"")
        XCTAssertEqual(span.attrs["link.spanId"], "b7ad6b7169203331")
        XCTAssertEqual(span.attrs["link.traceId"], "0af7651916cd43dd8448eb211c80319c")
    }
    func testSingleQuote() throws {
        let span = TestSpan()
        addLinkToSpan(span: span, valStr: "traceparent;desc='00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01'")
        XCTAssertEqual(span.attrs["link.spanId"], "b7ad6b7169203331")
        XCTAssertEqual(span.attrs["link.traceId"], "0af7651916cd43dd8448eb211c80319c")

    }
    func testDoesNotThrow() throws {
        let span = TestSpan()
        let tests = [
            "",
            "bogusvalue",
            "traceparent;desc=\"00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-00", // not sampled
            "traceparent;desc=\"00-0af7651916cd43dd8448eb211c8019c-b7ad6b7169203331-01", // traceid short
            "traceparent;desc=\"00-0af7651916cd43dd8448eb211c80319c-b7ad67169203331-01", // spanid short
            "traceparent;desc=\"01-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01" // futureversion

        ]
        tests.forEach {
            addLinkToSpan(span: span, valStr: $0)
            XCTAssertEqual(span.attrs.count, 0)
        }

    }

}
