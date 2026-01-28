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
@testable import SplunkNetwork

final class IPAddressValidationTests: XCTestCase {

    // MARK: - IPv4 Tests

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

    // MARK: - IPv6 Tests

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
}
