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

import OpenTelemetryApi
@testable import SplunkAgent
import XCTest

final class MutableAttributesSubscriptTests: XCTestCase {

    // MARK: - Subscript Tests

    func testBasicSubscript() {
        let attributes = MutableAttributes()

        attributes["string"] = .string("value")
        attributes["int"] = .int(42)
        attributes["bool"] = .bool(true)
        XCTAssertEqual(attributes["string"], .string("value"))
        XCTAssertEqual(attributes["int"], .int(42))
        XCTAssertEqual(attributes["bool"], .bool(true))

        attributes["string"] = nil
        XCTAssertNil(attributes["string"])
    }

    func testStringSubscript() {
        let attributes = MutableAttributes()

        attributes[string: "name"] = "John Doe"
        XCTAssertEqual(attributes[string: "name"], "John Doe")

        attributes[string: "name"] = nil
        XCTAssertNil(attributes[string: "name"])
    }

    func testBoolSubscript() {
        let attributes = MutableAttributes()

        attributes[bool: "active"] = true
        XCTAssertEqual(attributes[bool: "active"], true)

        attributes[bool: "active"] = nil
        XCTAssertNil(attributes[bool: "active"])
    }

    func testIntSubscript() {
        let attributes = MutableAttributes()

        attributes[int: "age"] = 30
        XCTAssertEqual(attributes[int: "age"], 30)

        // Remove value
        attributes[int: "age"] = nil
        XCTAssertNil(attributes[int: "age"])
    }

    func testDoubleSubscript() {
        let attributes = MutableAttributes()

        attributes[double: "score"] = 98.5
        XCTAssertEqual(attributes[double: "score"], 98.5)

        attributes[double: "score"] = nil
        XCTAssertNil(attributes[double: "score"])
    }

    func testArraySubscript() {
        let attributes = MutableAttributes()
        let array = AttributeArray(values: [.string("item1"), .string("item2")])

        attributes[array: "items"] = array
        XCTAssertEqual(attributes[array: "items"], array)

        attributes[array: "items"] = nil
        XCTAssertNil(attributes[array: "items"])
    }

    func testSetSubscript() {
        let attributes = MutableAttributes()
        let attributeSet = AttributeSet(labels: [
            "name": .string("John Doe"),
            "age": .int(30)
        ])

        attributes[set: "user"] = attributeSet
        XCTAssertEqual(attributes[set: "user"], attributeSet)

        attributes[set: "user"] = nil
        XCTAssertNil(attributes[set: "user"])
    }
}
