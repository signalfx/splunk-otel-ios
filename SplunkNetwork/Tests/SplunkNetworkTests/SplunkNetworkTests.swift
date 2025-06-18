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

import XCTest
import OpenTelemetryApi
import OpenTelemetrySdk
import URLSessionInstrumentation
@testable import SplunkNetwork
import XCTest

final class SplunkNetworkTests: XCTestCase {
    var sut: NetworkInstrumentation!
    
    // Mock IgnoreURLs
    class MockIgnoreURLs: IgnoreURLs {
        var shouldMatch = false
        
        override func matches(url: URL) -> Bool {
            return shouldMatch
        }
    }
    
    // Mock Span that conforms to all required protocols
    class MockSpan: Span {
        var attributes: [String: AttributeValue] = [:]
        var events: [SpanData.Event] = []
        var links: [SpanData.Link] = []
        var startTime: Date = Date()
        var endTime: Date?
        var hasEnded: Bool = false
        var totalRecordedEvents: Int = 0
        var totalRecordedLinks: Int = 0
        var totalAttributeCount: Int = 0
        var parentSpanId: SpanId?
        var instrumentationScopeInfo: InstrumentationScopeInfo = InstrumentationScopeInfo()
        
        // Required SpanBase properties
        var kind: SpanKind { return .internal }
        var context: SpanContext
        var isRecording: Bool { return true }
        var status: Status = .unset
        var name: String = "MockSpan"
        
        init() {
            let traceId = TraceId.random()
            let spanId = SpanId.random()
            let traceFlags = TraceFlags()
            let traceState = TraceState()
            self.context = SpanContext.create(traceId: traceId, spanId: spanId, traceFlags: traceFlags, traceState: traceState)
        }
        
        func setAttribute(key: String, value: Any) {
            if let stringValue = value as? String {
                attributes[key] = .string(stringValue)
            } else if let intValue = value as? Int {
                attributes[key] = .int(intValue)
            } else if let doubleValue = value as? Double {
                attributes[key] = .double(doubleValue)
            } else if let boolValue = value as? Bool {
                attributes[key] = .bool(boolValue)
            }
        }
        
        // Required SpanBase methods
        func setAttribute(key: String, value: AttributeValue?) {
            if let value = value {
                attributes[key] = value
            }
        }
        
        func addEvent(name: String) {}
        func addEvent(name: String, timestamp: Date) {}
        func addEvent(name: String, attributes: [String: AttributeValue]) {}
        func addEvent(name: String, attributes: [String: AttributeValue], timestamp: Date) {}
        
        // Required Span methods
        func end() {}
        func end(time: Date) {}
        
        // Required SpanExceptionRecorder methods
        func recordException(_ exception: SpanException) {}
        func recordException(_ exception: SpanException, timestamp: Date) {}
        func recordException(_ exception: SpanException, attributes: [String: AttributeValue]) {}
        func recordException(_ exception: SpanException, attributes: [String: AttributeValue], timestamp: Date) {}
        
        // CustomStringConvertible
        var description: String { return "MockSpan" }
    }
    
    override func setUp() {
        super.setUp()
        sut = NetworkInstrumentation()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - shouldInstrument Tests
    
    func testShouldInstrument_WithExcludedEndpoint_ReturnsFalse() {
        // Given
        let excludedURL = URL(string: "https://excluded.com")!
        sut.excludedEndpoints = [excludedURL]
        let request = URLRequest(url: excludedURL)
        
        // When
        let result = sut.shouldInstrument(URLRequest: request)
        
        // Then
        XCTAssertFalse(result)
    }
    
    func testShouldInstrument_WithLocalhost_ReturnsFalse() {
        // Given
        let localhostURL = URL(string: "http://localhost:8080")!
        let request = URLRequest(url: localhostURL)
        
        // When
        let result = sut.shouldInstrument(URLRequest: request)
        
        // Then
        XCTAssertFalse(result)
    }
    
    func testShouldInstrument_WithValidURL_ReturnsTrue() {
        // Given
        let validURL = URL(string: "https://example.com")!
        sut.excludedEndpoints = [URL(string: "https://excluded.com")!]
        let request = URLRequest(url: validURL)
        
        // When
        let result = sut.shouldInstrument(URLRequest: request)
        
        // Then
        XCTAssertTrue(result)
    }
    
    func testShouldInstrument_WithNoExcludedEndpoints_ReturnsFalse() {
        // Given
        let validURL = URL(string: "https://example.com")!
        sut.excludedEndpoints = nil
        let request = URLRequest(url: validURL)
        
        // When
        let result = sut.shouldInstrument(URLRequest: request)
        
        // Then
        XCTAssertFalse(result)
    }
    
    // MARK: - shouldRecordPayload Tests
    
    func testShouldRecordPayload_AlwaysReturnsTrue() {
        // Given
        let session = URLSession.shared
        
        // When
        let result = sut.shouldRecordPayload(URLSession: session)
        
        // Then
        XCTAssertTrue(result)
    }
    
    // MARK: - createdRequest Tests
    
    func testCreatedRequest_SetsContentLengthAttribute() {
        // Given
        let body = "test body".data(using: .utf8)!
        var request = URLRequest(url: URL(string: "https://example.com")!)
        request.httpBody = body
        
        let mockSpan = MockSpan()
        
        // When
        sut.createdRequest(URLRequest: request, span: mockSpan)
        
        // Then
        let attributeValue = mockSpan.attributes[SemanticAttributes.httpRequestContentLength.rawValue]
        XCTAssertNotNil(attributeValue)
        if case .int(let value) = attributeValue {
            XCTAssertEqual(value, body.count)
        } else {
            XCTFail("Expected int attribute value")
        }
    }
    
    // MARK: - receivedResponse Tests
    
    func testReceivedResponse_SetsContentLengthAttribute() {
        // Given
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        
        let mockSpan = MockSpan()
        
        // When
        sut.receivedResponse(URLResponse: response, dataOrFile: nil, span: mockSpan)
        
        // Then
        let attributeValue = mockSpan.attributes[SemanticAttributes.httpResponseContentLength.rawValue]
        XCTAssertNotNil(attributeValue)
        if case .int = attributeValue {
            // Success - we just want to verify it's an int value
        } else {
            XCTFail("Expected int attribute value")
        }
    }
    
    func testReceivedResponse_WithServerTiming_AddsLinkToSpan() {
        // Given
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["server-timing": "traceparent;desc='00-1234567890abcdef1234567890abcdef-1234567890abcdef-01'"]
        )!
        
        let mockSpan = MockSpan()
        
        // When
        sut.receivedResponse(URLResponse: response, dataOrFile: nil, span: mockSpan)
        
        // Then
        let traceIdValue = mockSpan.attributes["link.traceId"]
        let spanIdValue = mockSpan.attributes["link.spanId"]
        
        XCTAssertNotNil(traceIdValue)
        XCTAssertNotNil(spanIdValue)
        
        if case .string(let traceId) = traceIdValue {
            XCTAssertEqual(traceId, "1234567890abcdef1234567890abcdef")
        } else {
            XCTFail("Expected string attribute value for traceId")
        }
        
        if case .string(let spanId) = spanIdValue {
            XCTAssertEqual(spanId, "1234567890abcdef")
        } else {
            XCTFail("Expected string attribute value for spanId")
        }
    }
}
