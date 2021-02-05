//
//  ServerTimingTests.swift
//
//  Created by jbley on 1/30/21.
//

import OpenTelemetryApi
import XCTest
import SplunkRum

class TestSpan : Span {
    public var attrs: Dictionary<String,String>
    func setAttribute(key: String, value: AttributeValue?) {
        attrs.updateValue(value!.description, forKey: key)
    }
    
    public init() {
        attrs = Dictionary()
        kind = .internal
        isRecordingEvents = true
        name = "test"
        description = "test"
        context = SpanContext.invalid
    }
    var kind: SpanKind
    
    var context: SpanContext
    
    var isRecordingEvents: Bool
    
    var status: Status?
    
    var name: String
    
    func addEvent(name: String) {
    }
    
    func addEvent(name: String, timestamp: Date) {
    }
    
    func addEvent(name: String, attributes: [String : AttributeValue]) {
    }
    
    func addEvent(name: String, attributes: [String : AttributeValue], timestamp: Date) {
    }
    
    func addEvent<E>(event: E) where E : Event {
    }
    
    func addEvent<E>(event: E, timestamp: Date) where E : Event {
    }
    
    var description: String
    
    
}

class ServerTimingTests: XCTestCase {

    func testBasicBehavior() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        let span = TestSpan()
        addLinkToSpan(span: span, valStr: "traceparent;desc=\"00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01\"")
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
            "traceparent;desc=\"01-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01", // futureversion

        ]
        tests.forEach {
            addLinkToSpan(span: span, valStr: $0)
            XCTAssertEqual(span.attrs.count, 0)
        }

    }


}
