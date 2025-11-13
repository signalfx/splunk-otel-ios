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

final class URLExclusionTests: XCTestCase {

    func testShouldExcludeURL_ExactHostMatch() throws {
        let url = try XCTUnwrap(URL(string: "https://api.example.com/v1/data"))
        let excludedEndpoints = try [
            XCTUnwrap(URL(string: "https://api.example.com"))
        ]

        XCTAssertTrue(shouldExcludeURL(url, excludedEndpoints: excludedEndpoints))
    }

    func testShouldExcludeURL_DifferentHost_NoFalsePositive() throws {
        let url = try XCTUnwrap(URL(string: "https://api.company.com/v1/data"))
        let excludedEndpoints = try [
            XCTUnwrap(URL(string: "https://api.com"))
        ]

        // Should NOT match - api.company.com is different from api.com
        XCTAssertFalse(shouldExcludeURL(url, excludedEndpoints: excludedEndpoints))
    }

    func testShouldExcludeURL_PathPrefixMatch() throws {
        let url = try XCTUnwrap(URL(string: "https://api.example.com/v1/users/123"))
        let excludedEndpoints = try [
            XCTUnwrap(URL(string: "https://api.example.com/v1"))
        ]

        XCTAssertTrue(shouldExcludeURL(url, excludedEndpoints: excludedEndpoints))
    }

    func testShouldExcludeURL_PathNoMatch() throws {
        let url = try XCTUnwrap(URL(string: "https://api.example.com/v2/users"))
        let excludedEndpoints = try [
            XCTUnwrap(URL(string: "https://api.example.com/v1"))
        ]

        // Should NOT match - /v2/users doesn't start with /v1
        XCTAssertFalse(shouldExcludeURL(url, excludedEndpoints: excludedEndpoints))
    }

    func testShouldExcludeURL_SchemeMatch() throws {
        let url = try XCTUnwrap(URL(string: "https://api.example.com/data"))
        let excludedEndpoints = try [
            XCTUnwrap(URL(string: "http://api.example.com"))
        ]

        // Should NOT match - https vs http
        XCTAssertFalse(shouldExcludeURL(url, excludedEndpoints: excludedEndpoints))
    }

    func testShouldExcludeURL_PortMatch() throws {
        let url = try XCTUnwrap(URL(string: "https://api.example.com:8080/data"))
        let excludedEndpoints = try [
            XCTUnwrap(URL(string: "https://api.example.com:8080"))
        ]

        XCTAssertTrue(shouldExcludeURL(url, excludedEndpoints: excludedEndpoints))
    }

    func testShouldExcludeURL_PortMismatch() throws {
        let url = try XCTUnwrap(URL(string: "https://api.example.com:8080/data"))
        let excludedEndpoints = try [
            XCTUnwrap(URL(string: "https://api.example.com:9090"))
        ]

        // Should NOT match - different ports
        XCTAssertFalse(shouldExcludeURL(url, excludedEndpoints: excludedEndpoints))
    }

    func testShouldExcludeURL_EmptyPath() throws {
        let url = try XCTUnwrap(URL(string: "https://api.example.com/any/path"))
        let excludedEndpoints = try [
            XCTUnwrap(URL(string: "https://api.example.com"))
        ]

        // Should match - empty path matches any path on same host
        XCTAssertTrue(shouldExcludeURL(url, excludedEndpoints: excludedEndpoints))
    }

    func testShouldExcludeURL_RootPath() throws {
        let url = try XCTUnwrap(URL(string: "https://api.example.com/any/path"))
        let excludedEndpoints = try [
            XCTUnwrap(URL(string: "https://api.example.com/"))
        ]

        // Should match - root path "/" matches any path on same host
        XCTAssertTrue(shouldExcludeURL(url, excludedEndpoints: excludedEndpoints))
    }

    func testShouldExcludeURL_CaseInsensitive() throws {
        let url = try XCTUnwrap(URL(string: "https://API.EXAMPLE.COM/data"))
        let excludedEndpoints = try [
            XCTUnwrap(URL(string: "https://api.example.com"))
        ]

        // Should match - host comparison is case-insensitive
        XCTAssertTrue(shouldExcludeURL(url, excludedEndpoints: excludedEndpoints))
    }

    func testShouldExcludeURL_MultipleEndpoints() throws {
        let url = try XCTUnwrap(URL(string: "https://api.example.com/data"))
        let excludedEndpoints = try [
            XCTUnwrap(URL(string: "https://other.com")),
            XCTUnwrap(URL(string: "https://api.example.com")),
            XCTUnwrap(URL(string: "https://another.com"))
        ]

        XCTAssertTrue(shouldExcludeURL(url, excludedEndpoints: excludedEndpoints))
    }

    func testShouldExcludeURL_NoMatch() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/data"))
        let excludedEndpoints = try [
            XCTUnwrap(URL(string: "https://api.com")),
            XCTUnwrap(URL(string: "https://other.com"))
        ]

        XCTAssertFalse(shouldExcludeURL(url, excludedEndpoints: excludedEndpoints))
    }
}

