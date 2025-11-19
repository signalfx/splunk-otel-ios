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
import XCTest

@testable import SplunkNetwork

final class HTTPAnalysisTests: XCTestCase {

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

    // MARK: - IP Address Extraction Tests

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
}
