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

// swift-format-ignore-file
// swiftlint:disable sorted_imports
import Foundation
import OpenTelemetryApi
import XCTest
@_spi(SplunkInternal) @testable import SplunkCommon

// swiftlint:enable sorted_imports

final class SpanExtensionsObjCBridgingTests: XCTestCase {

    // MARK: - Private

    private var mockSpan: MockSpan?


    // MARK: - Tests lifecycle

    override func setUp() {
        super.setUp()
        mockSpan = MockSpan(name: "test-span")
    }

    override func tearDown() {
        mockSpan = nil
        super.tearDown()
    }


    // MARK: - ObjC bridging: Bool vs numeric NSNumber values

    func testClearAndSetAttributeWithObjCBoolAny() throws {
        let mockSpan = try XCTUnwrap(mockSpan)

        // Given
        let key = "test.bool.objc"
        // NSNumber(value: true) is what @YES produces when bridged to Swift Any.
        let value: Any = NSNumber(value: true)

        // When
        mockSpan.clearAndSetAttribute(key: key, value: value)

        // Then
        XCTAssertEqual(mockSpan.attributes[key], AttributeValue.bool(true))
    }

    func testClearAndSetAttributeWithObjCIntegerOneAny() throws {
        let mockSpan = try XCTUnwrap(mockSpan)

        // Given
        let key = "test.int.objc"
        let value: Any = NSNumber(value: 1)

        // When
        mockSpan.clearAndSetAttribute(key: key, value: value)

        // Then
        XCTAssertEqual(mockSpan.attributes[key], AttributeValue.int(1))
    }

    func testClearAndSetAttributeWithObjCDoubleWholeNumberAny() throws {
        let mockSpan = try XCTUnwrap(mockSpan)

        // Given
        let key = "test.double.objc"
        let value: Any = NSNumber(value: 1.0)

        // When
        mockSpan.clearAndSetAttribute(key: key, value: value)

        // Then
        XCTAssertEqual(mockSpan.attributes[key], AttributeValue.double(1.0))
    }

    func testClearAndSetAttributeWithObjCBoolArrayAny() throws {
        let mockSpan = try XCTUnwrap(mockSpan)

        // Given
        let key = "test.bool.array.objc"
        // An array of NSNumber booleans as bridged from ObjC (@[@YES, @NO]).
        let value: Any = [NSNumber(value: true), NSNumber(value: false)]

        // When
        mockSpan.clearAndSetAttribute(key: key, value: value)

        // Then
        let expectedArray = AttributeArray(values: [AttributeValue.bool(true), AttributeValue.bool(false)])
        XCTAssertEqual(mockSpan.attributes[key], AttributeValue.array(expectedArray))
    }

    func testClearAndSetAttributeWithObjCIntegerArrayAny() throws {
        let mockSpan = try XCTUnwrap(mockSpan)

        // Given
        let key = "test.int.array.objc"
        let value: Any = [NSNumber(value: 1), NSNumber(value: 0)]

        // When
        mockSpan.clearAndSetAttribute(key: key, value: value)

        // Then
        let expectedArray = AttributeArray(values: [AttributeValue.int(1), AttributeValue.int(0)])
        XCTAssertEqual(mockSpan.attributes[key], AttributeValue.array(expectedArray))
    }
}
