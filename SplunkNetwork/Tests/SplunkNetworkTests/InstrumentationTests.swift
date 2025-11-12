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

final class InstrumentationTests: XCTestCase {

    // MARK: - Mock Objects

    private class MockHTTPURLResponse: HTTPURLResponse, @unchecked Sendable {
        private let mockStatusCode: Int
        private let mockHeaders: [String: Any]

        init(statusCode: Int, headers: [String: Any] = [:]) {
            mockStatusCode = statusCode
            mockHeaders = headers

            // swiftlint:disable force_unwrapping
            super
                .init(
                    url: URL(string: "https://example.com")!,
                    statusCode: statusCode,
                    httpVersion: "HTTP/1.1",
                    headerFields: headers as? [String: String]
                )!
            // swiftlint:enable force_unwrapping
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override var statusCode: Int {
            mockStatusCode
        }

        override var allHeaderFields: [AnyHashable: Any] {
            mockHeaders
        }
    }

    // MARK: - IP Address Validation Tests

    func testIsValidIPAddress_ValidIPv4() {
        XCTAssertTrue(isValidIPAddress("192.168.1.1"))
        XCTAssertTrue(isValidIPAddress("10.0.0.0"))
        XCTAssertTrue(isValidIPAddress("255.255.255.255"))
        XCTAssertTrue(isValidIPAddress("127.0.0.1"))
        XCTAssertTrue(isValidIPAddress("8.8.8.8"))
    }

    func testIsValidIPAddress_InvalidIPv4() {
        XCTAssertFalse(isValidIPAddress("256.1.1.1")) // Out of range
        XCTAssertFalse(isValidIPAddress("192.168.1")) // Too few octets
        XCTAssertFalse(isValidIPAddress("192.168.1.1.1")) // Too many octets
        XCTAssertFalse(isValidIPAddress("abc.def.ghi.jkl")) // Non-numeric
        XCTAssertFalse(isValidIPAddress("")) // Empty string
    }

    func testIsValidIPAddress_ValidIPv6() {
        // Full-form IPv6
        XCTAssertTrue(isValidIPAddress("2001:0db8:85a3:0000:0000:8a2e:0370:7334"))

        // Loopback and special addresses
        XCTAssertTrue(isValidIPAddress("::1")) // Loopback
        XCTAssertTrue(isValidIPAddress("::")) // All zeros

        // Compressed IPv6 addresses
        XCTAssertTrue(isValidIPAddress("2001:db8::1"))
        XCTAssertTrue(isValidIPAddress("fe80::1:2:3"))
        XCTAssertTrue(isValidIPAddress("2001:db8::8a2e:370:7334"))
        XCTAssertTrue(isValidIPAddress("::ffff:192.0.2.1")) // IPv4-mapped IPv6

        // Link-local addresses
        XCTAssertTrue(isValidIPAddress("fe80::"))
        XCTAssertTrue(isValidIPAddress("fe80::1"))
    }

    func testIsValidIPAddress_InvalidIPv6() {
        XCTAssertFalse(isValidIPAddress("2001:0db8:85a3::8a2e:0370:7334:extra")) // Too many groups
        XCTAssertFalse(isValidIPAddress("gggg:0db8:85a3:0000:0000:8a2e:0370:7334")) // Invalid hex
        XCTAssertFalse(isValidIPAddress("2001:0db8")) // Too few groups
        XCTAssertFalse(isValidIPAddress("::gggg")) // Invalid hex in compressed form
        XCTAssertFalse(isValidIPAddress("2001:db8:::1")) // Triple colon (invalid)
    }

    // MARK: - URL Exclusion Tests

    func testShouldExcludeURL_ExactHostMatch() throws {
        let url = try XCTUnwrap(URL(string: "https://api.example.com/v1/data"))
        let excludedEndpoints = [
            try XCTUnwrap(URL(string: "https://api.example.com"))
        ]

        XCTAssertTrue(shouldExcludeURL(url, excludedEndpoints: excludedEndpoints))
    }

    func testShouldExcludeURL_DifferentHost_NoFalsePositive() throws {
        let url = try XCTUnwrap(URL(string: "https://api.company.com/v1/data"))
        let excludedEndpoints = [
            try XCTUnwrap(URL(string: "https://api.com"))
        ]

        // Should NOT match - api.company.com is different from api.com
        XCTAssertFalse(shouldExcludeURL(url, excludedEndpoints: excludedEndpoints))
    }

    func testShouldExcludeURL_PathPrefixMatch() throws {
        let url = try XCTUnwrap(URL(string: "https://api.example.com/v1/users/123"))
        let excludedEndpoints = [
            try XCTUnwrap(URL(string: "https://api.example.com/v1"))
        ]

        XCTAssertTrue(shouldExcludeURL(url, excludedEndpoints: excludedEndpoints))
    }

    func testShouldExcludeURL_PathNoMatch() throws {
        let url = try XCTUnwrap(URL(string: "https://api.example.com/v2/users"))
        let excludedEndpoints = [
            try XCTUnwrap(URL(string: "https://api.example.com/v1"))
        ]

        // Should NOT match - /v2/users doesn't start with /v1
        XCTAssertFalse(shouldExcludeURL(url, excludedEndpoints: excludedEndpoints))
    }

    func testShouldExcludeURL_SchemeMatch() throws {
        let url = try XCTUnwrap(URL(string: "https://api.example.com/data"))
        let excludedEndpoints = [
            try XCTUnwrap(URL(string: "http://api.example.com"))
        ]

        // Should NOT match - https vs http
        XCTAssertFalse(shouldExcludeURL(url, excludedEndpoints: excludedEndpoints))
    }

    func testShouldExcludeURL_PortMatch() throws {
        let url = try XCTUnwrap(URL(string: "https://api.example.com:8080/data"))
        let excludedEndpoints = [
            try XCTUnwrap(URL(string: "https://api.example.com:8080"))
        ]

        XCTAssertTrue(shouldExcludeURL(url, excludedEndpoints: excludedEndpoints))
    }

    func testShouldExcludeURL_PortMismatch() throws {
        let url = try XCTUnwrap(URL(string: "https://api.example.com:8080/data"))
        let excludedEndpoints = [
            try XCTUnwrap(URL(string: "https://api.example.com:9090"))
        ]

        // Should NOT match - different ports
        XCTAssertFalse(shouldExcludeURL(url, excludedEndpoints: excludedEndpoints))
    }

    func testShouldExcludeURL_EmptyPath() throws {
        let url = try XCTUnwrap(URL(string: "https://api.example.com/any/path"))
        let excludedEndpoints = [
            try XCTUnwrap(URL(string: "https://api.example.com"))
        ]

        // Should match - empty path matches any path on same host
        XCTAssertTrue(shouldExcludeURL(url, excludedEndpoints: excludedEndpoints))
    }

    func testShouldExcludeURL_RootPath() throws {
        let url = try XCTUnwrap(URL(string: "https://api.example.com/any/path"))
        let excludedEndpoints = [
            try XCTUnwrap(URL(string: "https://api.example.com/"))
        ]

        // Should match - root path "/" matches any path on same host
        XCTAssertTrue(shouldExcludeURL(url, excludedEndpoints: excludedEndpoints))
    }

    func testShouldExcludeURL_CaseInsensitive() throws {
        let url = try XCTUnwrap(URL(string: "https://API.EXAMPLE.COM/data"))
        let excludedEndpoints = [
            try XCTUnwrap(URL(string: "https://api.example.com"))
        ]

        // Should match - host comparison is case-insensitive
        XCTAssertTrue(shouldExcludeURL(url, excludedEndpoints: excludedEndpoints))
    }

    func testShouldExcludeURL_MultipleEndpoints() throws {
        let url = try XCTUnwrap(URL(string: "https://api.example.com/data"))
        let excludedEndpoints = [
            try XCTUnwrap(URL(string: "https://other.com")),
            try XCTUnwrap(URL(string: "https://api.example.com")),
            try XCTUnwrap(URL(string: "https://another.com"))
        ]

        XCTAssertTrue(shouldExcludeURL(url, excludedEndpoints: excludedEndpoints))
    }

    func testShouldExcludeURL_NoMatch() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/data"))
        let excludedEndpoints = [
            try XCTUnwrap(URL(string: "https://api.com")),
            try XCTUnwrap(URL(string: "https://other.com"))
        ]

        XCTAssertFalse(shouldExcludeURL(url, excludedEndpoints: excludedEndpoints))
    }

    // MARK: - Supported Task Tests

    func testIsSupportedTask_DataTask() throws {
        let session = URLSession.shared
        let url = try XCTUnwrap(URL(string: "https://example.com"))
        let task = session.dataTask(with: url)

        XCTAssertTrue(isSupportedTask(task: task))

        task.cancel()
    }

    func testIsSupportedTask_DownloadTask() throws {
        let session = URLSession.shared
        let url = try XCTUnwrap(URL(string: "https://example.com"))
        let task = session.downloadTask(with: url)

        XCTAssertTrue(isSupportedTask(task: task))

        task.cancel()
    }

    func testIsSupportedTask_UploadTask() throws {
        let session = URLSession.shared
        let url = try XCTUnwrap(URL(string: "https://example.com"))
        let data = Data()
        let task = session.uploadTask(with: URLRequest(url: url), from: data)

        XCTAssertTrue(isSupportedTask(task: task))

        task.cancel()
    }

    func testIsSupportedTask_StreamTask() {
        let session = URLSession.shared
        let task = session.streamTask(withHostName: "example.com", port: 443)

        // Stream tasks are not supported
        XCTAssertFalse(isSupportedTask(task: task))

        task.cancel()
    }

    // MARK: - HTTP Protocol Version Tests

    func testDetermineHTTPProtocolVersion_HTTP2_FromServerHeader() {
        let response = MockHTTPURLResponse(
            statusCode: 200,
            headers: ["Server": "nginx/1.18.0 HTTP/2"]
        )

        XCTAssertEqual(determineHTTPProtocolVersion(response), "2.0")
    }

    func testDetermineHTTPProtocolVersion_HTTP2_FromH2() {
        let response = MockHTTPURLResponse(
            statusCode: 200,
            headers: ["Server": "Apache h2"]
        )

        XCTAssertEqual(determineHTTPProtocolVersion(response), "2.0")
    }

    func testDetermineHTTPProtocolVersion_HTTP2_FromSpdyHeader() {
        let response = MockHTTPURLResponse(
            statusCode: 200,
            headers: ["X-Firefox-Spdy": "h2"]
        )

        XCTAssertEqual(determineHTTPProtocolVersion(response), "2.0")
    }

    func testDetermineHTTPProtocolVersion_HTTP1_1_Default() {
        let response = MockHTTPURLResponse(
            statusCode: 200,
            headers: ["Server": "Apache/2.4.41"]
        )

        XCTAssertEqual(determineHTTPProtocolVersion(response), "1.1")
    }

    func testDetermineHTTPProtocolVersion_HTTP1_1_NoHeaders() {
        let response = MockHTTPURLResponse(statusCode: 200)

        XCTAssertEqual(determineHTTPProtocolVersion(response), "1.1")
    }

    // MARK: - Get IP Address From Response Tests

    func testGetIPAddressFromResponse_XForwardedFor() {
        let response = MockHTTPURLResponse(
            statusCode: 200,
            headers: ["X-Forwarded-For": "203.0.113.195, 70.41.3.18, 150.172.238.178"]
        )

        XCTAssertEqual(getIPAddressFromResponse(response), "203.0.113.195")
    }

    func testGetIPAddressFromResponse_XForwardedFor_SingleIP() {
        let response = MockHTTPURLResponse(
            statusCode: 200,
            headers: ["X-Forwarded-For": "203.0.113.195"]
        )

        XCTAssertEqual(getIPAddressFromResponse(response), "203.0.113.195")
    }

    func testGetIPAddressFromResponse_XForwardedFor_InvalidIP() {
        let response = MockHTTPURLResponse(
            statusCode: 200,
            headers: ["X-Forwarded-For": "invalid-ip, 203.0.113.195"]
        )

        XCTAssertNil(getIPAddressFromResponse(response))
    }

    func testGetIPAddressFromResponse_XRealIP() {
        let response = MockHTTPURLResponse(
            statusCode: 200,
            headers: ["X-Real-IP": "198.51.100.42"]
        )

        XCTAssertEqual(getIPAddressFromResponse(response), "198.51.100.42")
    }

    func testGetIPAddressFromResponse_XRealIP_InvalidIP() {
        let response = MockHTTPURLResponse(
            statusCode: 200,
            headers: ["X-Real-IP": "not-an-ip-address"]
        )

        XCTAssertNil(getIPAddressFromResponse(response))
    }

    func testGetIPAddressFromResponse_NoHeaders() {
        let response = MockHTTPURLResponse(statusCode: 200)

        XCTAssertNil(getIPAddressFromResponse(response))
    }

    func testGetIPAddressFromResponse_PreferXForwardedFor() {
        let response = MockHTTPURLResponse(
            statusCode: 200,
            headers: [
                "X-Forwarded-For": "203.0.113.195",
                "X-Real-IP": "198.51.100.42"
            ]
        )

        // X-Forwarded-For should take precedence
        XCTAssertEqual(getIPAddressFromResponse(response), "203.0.113.195")
    }

    // MARK: - Add Link To Span Tests

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

    // MARK: - Mock Span Helper

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
}
