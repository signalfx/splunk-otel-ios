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

// swiftformat:disable sortImports
import Foundation
import OpenTelemetryApi
@_spi(SplunkInternal) @testable import SplunkCommon
import XCTest

final class SpanExtensionsTests: XCTestCase {

    private var mockSpan: MockSpan!

    override func setUp() {
        super.setUp()
        mockSpan = MockSpan(name: "test-span")
    }

    override func tearDown() {
        mockSpan = nil
        super.tearDown()
    }

    func testClearAndSetAttributeWithAttributeValue() {
        // Given: A span with an existing attribute
        let key = "test.attribute"
        let initialValue = AttributeValue.string("initial")
        let newValue = AttributeValue.string("new")

        mockSpan.setAttribute(key: key, value: initialValue)
        XCTAssertEqual(mockSpan.attributes[key], initialValue)

        // When: Clearing and setting a new value
        mockSpan.clearAndSetAttribute(key: key, value: newValue)

        // Then: The attribute should have the new value
        XCTAssertEqual(mockSpan.attributes[key], newValue)
    }

    func testClearAndSetAttributeWithDifferentAttributeValueTypes() {
        let key = "test.attribute"

        // Test with string value
        let stringValue = AttributeValue.string("test")
        mockSpan.clearAndSetAttribute(key: key, value: stringValue)
        XCTAssertEqual(mockSpan.attributes[key], stringValue)

        // Test with int value
        let intValue = AttributeValue.int(42)
        mockSpan.clearAndSetAttribute(key: key, value: intValue)
        XCTAssertEqual(mockSpan.attributes[key], intValue)

        // Test with double value
        let doubleValue = AttributeValue.double(3.14)
        mockSpan.clearAndSetAttribute(key: key, value: doubleValue)
        XCTAssertEqual(mockSpan.attributes[key], doubleValue)

        // Test with bool value
        let boolValue = AttributeValue.bool(true)
        mockSpan.clearAndSetAttribute(key: key, value: boolValue)
        XCTAssertEqual(mockSpan.attributes[key], boolValue)
    }

    func testClearAndSetAttributeWithStringAny() {
        // Given
        let key = "test.string"
        let value = "test string"

        // When
        mockSpan.clearAndSetAttribute(key: key, value: value)

        // Then
        XCTAssertEqual(mockSpan.attributes[key], AttributeValue.string(value))
    }

    func testClearAndSetAttributeWithIntAny() {
        // Given
        let key = "test.int"
        let value = 42

        // When
        mockSpan.clearAndSetAttribute(key: key, value: value)

        // Then
        XCTAssertEqual(mockSpan.attributes[key], AttributeValue.int(value))
    }

    func testClearAndSetAttributeWithDoubleAny() {
        // Given
        let key = "test.double"
        let value = 3.14159

        // When
        mockSpan.clearAndSetAttribute(key: key, value: value)

        // Then
        XCTAssertEqual(mockSpan.attributes[key], AttributeValue.double(value))
    }

    func testClearAndSetAttributeWithBoolAny() {
        // Given
        let key = "test.bool"
        let value = true

        // When
        mockSpan.clearAndSetAttribute(key: key, value: value)

        // Then
        XCTAssertEqual(mockSpan.attributes[key], AttributeValue.bool(value))
    }

    func testClearAndSetAttributeWithStringArrayAny() {
        // Given
        let key = "test.string.array"
        let value = ["first", "second", "third"]

        // When
        mockSpan.clearAndSetAttribute(key: key, value: value)

        // Then
        let expectedArray = AttributeArray(values: value.map { AttributeValue.string($0) })
        XCTAssertEqual(mockSpan.attributes[key], AttributeValue.array(expectedArray))
    }

    func testClearAndSetAttributeWithIntArrayAny() {
        // Given
        let key = "test.int.array"
        let value = [1, 2, 3, 4, 5]

        // When
        mockSpan.clearAndSetAttribute(key: key, value: value)

        // Then
        let expectedArray = AttributeArray(values: value.map { AttributeValue.int($0) })
        XCTAssertEqual(mockSpan.attributes[key], AttributeValue.array(expectedArray))
    }

    func testClearAndSetAttributeWithDoubleArrayAny() {
        // Given
        let key = "test.double.array"
        let value = [1.1, 2.2, 3.3]

        // When
        mockSpan.clearAndSetAttribute(key: key, value: value)

        // Then
        let expectedArray = AttributeArray(values: value.map { AttributeValue.double($0) })
        XCTAssertEqual(mockSpan.attributes[key], AttributeValue.array(expectedArray))
    }

    func testClearAndSetAttributeWithBoolArrayAny() {
        // Given
        let key = "test.bool.array"
        let value = [true, false, true]

        // When
        mockSpan.clearAndSetAttribute(key: key, value: value)

        // Then
        let expectedArray = AttributeArray(values: value.map { AttributeValue.bool($0) })
        XCTAssertEqual(mockSpan.attributes[key], AttributeValue.array(expectedArray))
    }

    func testClearAndSetAttributeWithUnsupportedTypeAny() {
        // Given: An unsupported type (custom struct)
        struct CustomType {
            let value = "test"
        }
        let key = "test.custom"
        let value = CustomType()

        // When
        mockSpan.clearAndSetAttribute(key: key, value: value)

        // Then: Should convert to string representation
        let expectedStringValue = String(describing: value)
        XCTAssertEqual(mockSpan.attributes[key], AttributeValue.string(expectedStringValue))
    }

    func testClearAndSetAttributeWithEmptyStringArray() {
        // Given
        let key = "test.empty.array"
        let value: [String] = []

        // When
        mockSpan.clearAndSetAttribute(key: key, value: value)

        // Then
        let expectedArray = AttributeArray(values: [])
        XCTAssertEqual(mockSpan.attributes[key], AttributeValue.array(expectedArray))
    }

    func testClearAndSetAttributeWithSemanticAttributesAndAttributeValue() {
        // Given
        let semanticKey = SemanticAttributes.httpMethod
        let value = AttributeValue.string("GET")

        // When
        mockSpan.clearAndSetAttribute(key: semanticKey, value: value)

        // Then
        XCTAssertEqual(mockSpan.attributes[semanticKey.rawValue], value)
    }

    func testClearAndSetAttributeWithSemanticAttributesAndAny() {
        // Given
        let semanticKey = SemanticAttributes.httpStatusCode
        let value = 200

        // When
        mockSpan.clearAndSetAttribute(key: semanticKey, value: value)

        // Then
        XCTAssertEqual(mockSpan.attributes[semanticKey.rawValue], AttributeValue.int(value))
    }

    func testClearAndSetAttributeWithMultipleSemanticAttributes() {
        // Given
        let httpMethod = SemanticAttributes.httpMethod
        let httpUrl = SemanticAttributes.httpUrl
        let httpStatusCode = SemanticAttributes.httpStatusCode

        // When
        mockSpan.clearAndSetAttribute(key: httpMethod, value: "POST")
        mockSpan.clearAndSetAttribute(key: httpUrl, value: "https://api.example.com")
        mockSpan.clearAndSetAttribute(key: httpStatusCode, value: 201)

        // Then
        XCTAssertEqual(mockSpan.attributes[httpMethod.rawValue], AttributeValue.string("POST"))
        XCTAssertEqual(mockSpan.attributes[httpUrl.rawValue], AttributeValue.string("https://api.example.com"))
        XCTAssertEqual(mockSpan.attributes[httpStatusCode.rawValue], AttributeValue.int(201))
    }

    func testClearAndSetAttributeOverwritesExistingValue() {
        // Given: A span with an existing attribute
        let key = "test.overwrite"
        let initialValue = AttributeValue.string("initial")
        let newValue = AttributeValue.int(42)

        mockSpan.setAttribute(key: key, value: initialValue)
        XCTAssertEqual(mockSpan.attributes[key], initialValue)

        // When: Clearing and setting a new value of different type
        mockSpan.clearAndSetAttribute(key: key, value: newValue)

        // Then: The attribute should have the new value
        XCTAssertEqual(mockSpan.attributes[key], newValue)
    }

    func testClearAndSetAttributeWithNilValues() {
        // Given
        let key = "test.nil"
        let initialValue = AttributeValue.string("initial")

        mockSpan.setAttribute(key: key, value: initialValue)
        XCTAssertEqual(mockSpan.attributes[key], initialValue)

        // When: Setting a new value after clearing
        let newValue = AttributeValue.bool(false)
        mockSpan.clearAndSetAttribute(key: key, value: newValue)

        // Then: The attribute should have the new value
        XCTAssertEqual(mockSpan.attributes[key], newValue)
    }

    func testMultipleClearAndSetOperations() {
        // Given
        let key = "test.multiple"

        // When: Multiple clear and set operations
        mockSpan.clearAndSetAttribute(key: key, value: "first")
        XCTAssertEqual(mockSpan.attributes[key], AttributeValue.string("first"))

        mockSpan.clearAndSetAttribute(key: key, value: 42)
        XCTAssertEqual(mockSpan.attributes[key], AttributeValue.int(42))

        mockSpan.clearAndSetAttribute(key: key, value: true)
        XCTAssertEqual(mockSpan.attributes[key], AttributeValue.bool(true))

        mockSpan.clearAndSetAttribute(key: key, value: 3.14)
        XCTAssertEqual(mockSpan.attributes[key], AttributeValue.double(3.14))

        // Then: Final value should be the last one set
        XCTAssertEqual(mockSpan.attributes[key], AttributeValue.double(3.14))
    }

    func testClearAndSetAttributeWithSpecialStringValues() {
        let key = "test.special.strings"

        // Test with empty string
        mockSpan.clearAndSetAttribute(key: key, value: "")
        XCTAssertEqual(mockSpan.attributes[key], AttributeValue.string(""))

        // Test with whitespace string
        mockSpan.clearAndSetAttribute(key: key, value: "   ")
        XCTAssertEqual(mockSpan.attributes[key], AttributeValue.string("   "))

        // Test with unicode string
        mockSpan.clearAndSetAttribute(key: key, value: "🚀 Test 测试")
        XCTAssertEqual(mockSpan.attributes[key], AttributeValue.string("🚀 Test 测试"))
    }

    func testClearAndSetAttributeWithExtremeNumbers() {
        let key = "test.extreme.numbers"

        // Test with very large int
        mockSpan.clearAndSetAttribute(key: key, value: Int.max)
        XCTAssertEqual(mockSpan.attributes[key], AttributeValue.int(Int.max))

        // Test with very small int
        mockSpan.clearAndSetAttribute(key: key, value: Int.min)
        XCTAssertEqual(mockSpan.attributes[key], AttributeValue.int(Int.min))

        // Test with very large double
        mockSpan.clearAndSetAttribute(key: key, value: Double.greatestFiniteMagnitude)
        XCTAssertEqual(mockSpan.attributes[key], AttributeValue.double(Double.greatestFiniteMagnitude))

        // Test with very small double
        mockSpan.clearAndSetAttribute(key: key, value: Double.leastNormalMagnitude)
        XCTAssertEqual(mockSpan.attributes[key], AttributeValue.double(Double.leastNormalMagnitude))
    }
}

// MARK: - MockSpan for Testing

private class MockSpan: Span {
    var name: String
    var kind: SpanKind = .internal
    var context: SpanContext
    var status: Status = .unset
    var isRecording: Bool = true
    var startTime = Date()
    var endTime: Date?

    var attributes: [String: AttributeValue] = [:]

    init(name: String) {
        self.name = name
        context = SpanContext.create(
            traceId: TraceId.random(),
            spanId: SpanId.random(),
            traceFlags: TraceFlags(),
            traceState: TraceState()
        )
    }

    func setAttribute(key: String, value: AttributeValue?) {
        if let value {
            attributes[key] = value
        }
        else {
            attributes.removeValue(forKey: key)
        }
    }

    /// Required for full protocol conformance
    func setAttributes(_ attributes: [String: AttributeValue]) {
        for (key, value) in attributes {
            self.attributes[key] = value
        }
    }

    func recordException(_: any SpanException) {}
    func recordException(_: any SpanException, attributes _: [String: AttributeValue]) {}
    func recordException(_: any SpanException, timestamp _: Date) {}
    func recordException(_: any SpanException, attributes _: [String: AttributeValue], timestamp _: Date) {}

    func addEvent(name _: String, attributes _: [String: AttributeValue]) {}
    func addEvent(name _: String) {}
    func addEvent(name _: String, timestamp _: Date) {}
    func addEvent(name _: String, attributes _: [String: AttributeValue], timestamp _: Date) {}

    func end() {
        end(time: Date())
    }

    func end(time: Date) {
        isRecording = false
        endTime = time
    }

    var description: String {
        "MockSpan"
    }
}
