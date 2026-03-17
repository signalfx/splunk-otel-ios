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

import OpenTelemetryApi
import OpenTelemetrySdk
import XCTest

@testable import SplunkNetwork

final class CapturedHeadersTests: XCTestCase {

    private var sut: NetworkInstrumentation?

    override func setUp() {
        super.setUp()

        sut = NetworkInstrumentation()
    }

    override func tearDown() {
        sut?.uninstall()
        sut = nil

        super.tearDown()
    }


    // MARK: - Configuration Tests

    func testConfigurationDefaultsToNilHeaders() {
        let config = NetworkInstrumentationConfiguration(isEnabled: true, ignoreURLs: nil)

        XCTAssertNil(config.capturedRequestHeaders)
        XCTAssertNil(config.capturedResponseHeaders)
    }

    func testConfigurationAcceptsHeaderLists() {
        let config = NetworkInstrumentationConfiguration(
            capturedRequestHeaders: ["X-Request-ID", "Authorization"],
            capturedResponseHeaders: ["Content-Type", "X-RateLimit-Remaining"]
        )

        XCTAssertEqual(config.capturedRequestHeaders, ["X-Request-ID", "Authorization"])
        XCTAssertEqual(config.capturedResponseHeaders, ["Content-Type", "X-RateLimit-Remaining"])
    }

    func testFullInitPreservesAllParameters() throws {
        let ignoreURLs = try IgnoreURLs(patterns: Set([".*\\.png$"]))

        let config = NetworkInstrumentationConfiguration(
            isEnabled: false,
            ignoreURLs: ignoreURLs,
            capturedRequestHeaders: ["Accept"],
            capturedResponseHeaders: ["Server"]
        )

        XCTAssertFalse(config.isEnabled)
        XCTAssertNotNil(config.ignoreURLs)
        XCTAssertEqual(config.capturedRequestHeaders, ["Accept"])
        XCTAssertEqual(config.capturedResponseHeaders, ["Server"])
    }


    // MARK: - Module Storage Tests

    func testModuleStoresHeadersAsLowercased() {
        let config = NetworkInstrumentationConfiguration(
            capturedRequestHeaders: ["X-Request-ID", "Content-Type"],
            capturedResponseHeaders: ["X-RateLimit-Remaining", "Server"]
        )

        sut?.install(with: config, remoteConfiguration: nil)

        XCTAssertEqual(sut?.getCapturedRequestHeaders(), Set(["x-request-id", "content-type"]))
        XCTAssertEqual(sut?.getCapturedResponseHeaders(), Set(["x-ratelimit-remaining", "server"]))
    }

    func testModuleDefaultsToEmptyHeaderSets() {
        let config = NetworkInstrumentationConfiguration(isEnabled: true, ignoreURLs: nil)

        sut?.install(with: config, remoteConfiguration: nil)

        XCTAssertEqual(sut?.getCapturedRequestHeaders().isEmpty, true)
        XCTAssertEqual(sut?.getCapturedResponseHeaders().isEmpty, true)
    }

    func testModuleWithNilConfigDefaultsToEmptyHeaderSets() {
        sut?.install(with: nil, remoteConfiguration: nil)

        XCTAssertEqual(sut?.getCapturedRequestHeaders().isEmpty, true)
        XCTAssertEqual(sut?.getCapturedResponseHeaders().isEmpty, true)
    }


    // MARK: - Request Header Capture Tests

    func testRequestHeadersCapturedAsSpanAttributes() throws {
        let config = NetworkInstrumentationConfiguration(
            capturedRequestHeaders: ["X-Request-ID", "Accept"]
        )
        sut?.install(with: config, remoteConfiguration: nil)

        var request = URLRequest(url: try XCTUnwrap(URL(string: "https://example.com/api")))
        request.setValue("abc-123", forHTTPHeaderField: "X-Request-ID")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let span = MockSpan()
        addCapturedRequestHeaders(from: request, to: span)

        XCTAssertEqual(span.attributes["http.request.header.x-request-id"], .string("abc-123"))
        XCTAssertEqual(span.attributes["http.request.header.accept"], .string("application/json"))
    }

    func testRequestHeadersCaseInsensitiveMatching() throws {
        let config = NetworkInstrumentationConfiguration(
            capturedRequestHeaders: ["Content-Type"]
        )
        sut?.install(with: config, remoteConfiguration: nil)

        var request = URLRequest(url: try XCTUnwrap(URL(string: "https://example.com/api")))
        request.setValue("text/html", forHTTPHeaderField: "content-type")

        let span = MockSpan()
        addCapturedRequestHeaders(from: request, to: span)

        XCTAssertEqual(span.attributes["http.request.header.content-type"], .string("text/html"))
    }

    func testMissingRequestHeadersNotAddedToSpan() throws {
        let config = NetworkInstrumentationConfiguration(
            capturedRequestHeaders: ["X-Missing-Header"]
        )
        sut?.install(with: config, remoteConfiguration: nil)

        let request = URLRequest(url: try XCTUnwrap(URL(string: "https://example.com/api")))

        let span = MockSpan()
        addCapturedRequestHeaders(from: request, to: span)

        XCTAssertNil(span.attributes["http.request.header.x-missing-header"])
    }

    func testNoRequestHeadersCapturedWhenNotConfigured() throws {
        let config = NetworkInstrumentationConfiguration(isEnabled: true, ignoreURLs: nil)
        sut?.install(with: config, remoteConfiguration: nil)

        var request = URLRequest(url: try XCTUnwrap(URL(string: "https://example.com/api")))
        request.setValue("secret-value", forHTTPHeaderField: "Authorization")

        let span = MockSpan()
        addCapturedRequestHeaders(from: request, to: span)

        XCTAssertFalse(
            span.attributes.keys.contains { $0.hasPrefix("http.request.header.") },
            "No request headers should be captured when not configured"
        )
    }


    // MARK: - Response Header Capture Tests

    func testResponseHeadersCapturedAsSpanAttributes() throws {
        let config = NetworkInstrumentationConfiguration(
            capturedResponseHeaders: ["Content-Type", "X-Request-ID"]
        )
        sut?.install(with: config, remoteConfiguration: nil)

        let url = try XCTUnwrap(URL(string: "https://example.com/api"))
        let response = try XCTUnwrap(
            HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: [
                    "Content-Type": "application/json",
                    "X-Request-ID": "resp-456"
                ]
            )
        )

        let span = MockSpan()
        addCapturedResponseHeaders(from: response, to: span)

        XCTAssertEqual(span.attributes["http.response.header.content-type"], .string("application/json"))
        XCTAssertEqual(span.attributes["http.response.header.x-request-id"], .string("resp-456"))
    }

    func testResponseHeadersCaseInsensitiveMatching() throws {
        let config = NetworkInstrumentationConfiguration(
            capturedResponseHeaders: ["SERVER"]
        )
        sut?.install(with: config, remoteConfiguration: nil)

        let url = try XCTUnwrap(URL(string: "https://example.com/api"))
        let response = try XCTUnwrap(
            HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Server": "nginx"]
            )
        )

        let span = MockSpan()
        addCapturedResponseHeaders(from: response, to: span)

        XCTAssertEqual(span.attributes["http.response.header.server"], .string("nginx"))
    }

    func testMissingResponseHeadersNotAddedToSpan() throws {
        let config = NetworkInstrumentationConfiguration(
            capturedResponseHeaders: ["X-Missing-Header"]
        )
        sut?.install(with: config, remoteConfiguration: nil)

        let url = try XCTUnwrap(URL(string: "https://example.com/api"))
        let response = try XCTUnwrap(
            HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "text/plain"]
            )
        )

        let span = MockSpan()
        addCapturedResponseHeaders(from: response, to: span)

        XCTAssertNil(span.attributes["http.response.header.x-missing-header"])
    }

    func testNoResponseHeadersCapturedWhenNotConfigured() throws {
        let config = NetworkInstrumentationConfiguration(isEnabled: true, ignoreURLs: nil)
        sut?.install(with: config, remoteConfiguration: nil)

        let url = try XCTUnwrap(URL(string: "https://example.com/api"))
        let response = try XCTUnwrap(
            HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Set-Cookie": "session=abc"]
            )
        )

        let span = MockSpan()
        addCapturedResponseHeaders(from: response, to: span)

        XCTAssertFalse(
            span.attributes.keys.contains { $0.hasPrefix("http.response.header.") },
            "No response headers should be captured when not configured"
        )
    }


    // MARK: - Privacy Tests

    func testUnconfiguredHeadersAreNotLeaked() throws {
        let config = NetworkInstrumentationConfiguration(
            capturedRequestHeaders: ["Accept"],
            capturedResponseHeaders: ["Content-Type"]
        )
        sut?.install(with: config, remoteConfiguration: nil)

        var request = URLRequest(url: try XCTUnwrap(URL(string: "https://example.com/api")))
        request.setValue("Bearer secret-token", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let requestSpan = MockSpan()
        addCapturedRequestHeaders(from: request, to: requestSpan)

        XCTAssertNotNil(requestSpan.attributes["http.request.header.accept"])
        XCTAssertNil(
            requestSpan.attributes["http.request.header.authorization"],
            "Authorization header should not be captured when not in the configured list"
        )

        let url = try XCTUnwrap(URL(string: "https://example.com/api"))
        let response = try XCTUnwrap(
            HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: [
                    "Content-Type": "application/json",
                    "Set-Cookie": "session=secret"
                ]
            )
        )

        let responseSpan = MockSpan()
        addCapturedResponseHeaders(from: response, to: responseSpan)

        XCTAssertNotNil(responseSpan.attributes["http.response.header.content-type"])
        XCTAssertNil(
            responseSpan.attributes["http.response.header.set-cookie"],
            "Set-Cookie header should not be captured when not in the configured list"
        )
    }
}


// MARK: - Mock Span

private class MockSpan: Span {

    var attributes: [String: AttributeValue] = [:]
    var context: SpanContext
    var isRecording: Bool { true }
    var status: Status = .unset
    var name: String = "MockSpan"
    var kind: SpanKind { .internal }
    var instrumentationScopeInfo = InstrumentationScopeInfo()
    var description: String { "MockSpan" }

    init() {
        context = SpanContext.create(
            traceId: TraceId.random(),
            spanId: SpanId.random(),
            traceFlags: TraceFlags(),
            traceState: TraceState()
        )
    }

    func setAttribute(key: String, value: Any) {
        if let stringValue = value as? String {
            attributes[key] = .string(stringValue)
        }
        else if let intValue = value as? Int {
            attributes[key] = .int(intValue)
        }
        else if let boolValue = value as? Bool {
            attributes[key] = .bool(boolValue)
        }
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
    func end() {}
    func end(time _: Date) {}
    func recordException(_: SpanException) {}
    func recordException(_: SpanException, timestamp _: Date) {}
    func recordException(_: SpanException, attributes _: [String: AttributeValue]) {}
    func recordException(_: SpanException, attributes _: [String: AttributeValue], timestamp _: Date) {}
}
