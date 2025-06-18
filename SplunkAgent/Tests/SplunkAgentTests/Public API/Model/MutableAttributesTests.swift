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

final class MutableAttributesTests: XCTestCase {

    // MARK: - Initialization Tests

    func testEmptyInitialization() {
        let attributes = MutableAttributes()
        XCTAssertEqual(attributes.count(), 0)
        XCTAssertTrue(attributes.getAllKeys().isEmpty)
    }

    func testDictionaryInitialization() {
        let dictionary: [String: AttributeValue] = [
            "string": .string("value"),
            "int": .int(42),
            "bool": .bool(true)
        ]

        let attributes = MutableAttributes(dictionary: dictionary)
        XCTAssertEqual(attributes.count(), 3)
        XCTAssertEqual(attributes[string: "string"], "value")
        XCTAssertEqual(attributes[int: "int"], 42)
        XCTAssertEqual(attributes[bool: "bool"], true)
    }

    func testAttributeSetInitialization() {
        let attributeSet = AttributeSet(labels: [
            "string": .string("value"),
            "int": .int(42),
            "bool": .bool(true)
        ])

        let attributes = MutableAttributes(attributeSet: attributeSet)
        XCTAssertEqual(attributes.count(), 3)
        XCTAssertEqual(attributes[string: "string"], "value")
        XCTAssertEqual(attributes[int: "int"], 42)
        XCTAssertEqual(attributes[bool: "bool"], true)
    }

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

    // MARK: - Getter Tests

    func testGetValue() {
        let attributes = MutableAttributes()
        attributes["string"] = .string("value")

        XCTAssertEqual(attributes.getValue(for: "string"), .string("value"))
        XCTAssertNil(attributes.getValue(for: "nonexistent"))
    }

    func testGetString() {
        let attributes = MutableAttributes()
        attributes["string"] = .string("value")

        XCTAssertEqual(attributes.getString(for: "string"), "value")
        XCTAssertNil(attributes.getString(for: "nonexistent"))
        XCTAssertNil(attributes.getString(for: "int")) // Wrong type
    }

    func testGetBool() {
        let attributes = MutableAttributes()
        attributes["bool"] = .bool(true)

        XCTAssertEqual(attributes.getBool(for: "bool"), true)
        XCTAssertNil(attributes.getBool(for: "nonexistent"))
        XCTAssertNil(attributes.getBool(for: "string")) // Wrong type
    }

    func testGetInt() {
        let attributes = MutableAttributes()
        attributes["int"] = .int(42)

        XCTAssertEqual(attributes.getInt(for: "int"), 42)
        XCTAssertNil(attributes.getInt(for: "nonexistent"))
        XCTAssertNil(attributes.getInt(for: "string")) // Wrong type
    }

    func testGetDouble() {
        let attributes = MutableAttributes()
        attributes["double"] = .double(98.5)

        XCTAssertEqual(attributes.getDouble(for: "double"), 98.5)
        XCTAssertNil(attributes.getDouble(for: "nonexistent"))
        XCTAssertNil(attributes.getDouble(for: "string")) // Wrong type
    }

    func testGetArray() {
        let attributes = MutableAttributes()
        let array = AttributeArray(values: [.string("item1"), .string("item2")])
        attributes["array"] = .array(array)

        XCTAssertEqual(attributes.getArray(for: "array"), array)
        XCTAssertNil(attributes.getArray(for: "nonexistent"))
        XCTAssertNil(attributes.getArray(for: "string")) // Wrong type
    }

    func testGetSet() {
        let attributes = MutableAttributes()
        let attributeSet = AttributeSet(labels: [
            "name": .string("John Doe"),
            "age": .int(30)
        ])
        attributes["set"] = .set(attributeSet)

        XCTAssertEqual(attributes.getSet(for: "set"), attributeSet)
        XCTAssertNil(attributes.getSet(for: "nonexistent"))
        XCTAssertNil(attributes.getSet(for: "string")) // Wrong type
    }

    // MARK: - Setter Tests

    func testSetValue() {
        let attributes = MutableAttributes()
        attributes.setValue(.string("value"), for: "string")

        XCTAssertEqual(attributes["string"], .string("value"))
    }

    func testSetString() {
        let attributes = MutableAttributes()
        attributes.setString("value", for: "string")

        XCTAssertEqual(attributes["string"], .string("value"))
    }

    func testSetBool() {
        let attributes = MutableAttributes()
        attributes.setBool(true, for: "bool")

        XCTAssertEqual(attributes["bool"], .bool(true))
    }

    func testSetInt() {
        let attributes = MutableAttributes()
        attributes.setInt(42, for: "int")

        XCTAssertEqual(attributes["int"], .int(42))
    }

    func testSetDouble() {
        let attributes = MutableAttributes()
        attributes.setDouble(98.5, for: "double")

        XCTAssertEqual(attributes["double"], .double(98.5))
    }

    func testSetArray() {
        let attributes = MutableAttributes()
        let array = AttributeArray(values: [.string("item1"), .string("item2")])
        attributes.setArray(array, for: "array")

        XCTAssertEqual(attributes["array"], .array(array))
    }

    func testSetSet() {
        let attributes = MutableAttributes()
        let attributeSet = AttributeSet(labels: [
            "name": .string("John Doe"),
            "age": .int(30)
        ])
        attributes.setSet(attributeSet, for: "set")

        XCTAssertEqual(attributes["set"], .set(attributeSet))
    }

    // MARK: - Utility Tests

    func testRemoveValue() {
        let attributes = MutableAttributes()
        attributes["string"] = .string("value")

        attributes.remove(for: "string")
        XCTAssertNil(attributes["string"])
    }

    func testContains() {
        let attributes = MutableAttributes()
        attributes["string"] = .string("value")

        XCTAssertTrue(attributes.contains(key: "string"))
        XCTAssertFalse(attributes.contains(key: "nonexistent"))
    }

    func testGetAllKeys() {
        let attributes = MutableAttributes()
        attributes["string"] = .string("value")
        attributes["int"] = .int(42)

        let keys = attributes.getAllKeys()
        XCTAssertEqual(keys.count, 2)
        XCTAssertTrue(keys.contains("string"))
        XCTAssertTrue(keys.contains("int"))
    }

    func testGetAllValues() {
        let attributes = MutableAttributes()
        attributes["string"] = .string("value")
        attributes["int"] = .int(42)

        let values = attributes.getAllValues()
        XCTAssertEqual(values.count, 2)
        XCTAssertTrue(values.contains(.string("value")))
        XCTAssertTrue(values.contains(.int(42)))
    }

    func testClear() {
        let attributes = MutableAttributes()
        attributes["string"] = .string("value")
        attributes["int"] = .int(42)

        attributes.removeAll()
        XCTAssertEqual(attributes.count(), 0)
    }

    func testCount() {
        let attributes = MutableAttributes()
        XCTAssertEqual(attributes.count(), 0)

        attributes["string"] = .string("value")
        XCTAssertEqual(attributes.count(), 1)

        attributes["int"] = .int(42)
        XCTAssertEqual(attributes.count(), 2)

        attributes["string"] = nil
        XCTAssertEqual(attributes.count(), 1)
    }

    func testGetDictionary() {
        let attributes = MutableAttributes()
        attributes["string"] = .string("value")
        attributes["int"] = .int(42)

        let dictionary = attributes.getAll()
        XCTAssertEqual(dictionary.count, 2)
        XCTAssertEqual(dictionary["string"], .string("value"))
        XCTAssertEqual(dictionary["int"], .int(42))
    }

    // MARK: - Add AttributeSet Tests

    func testAddAttributeSet() {
        let attributes = MutableAttributes()
        let attributeSet = AttributeSet(labels: [
            "name": .string("John Doe"),
            "age": .int(30)
        ])

        let count = attributes.addAttributeSet(attributeSet)
        XCTAssertEqual(count, 2)
        XCTAssertEqual(attributes[string: "name"], "John Doe")
        XCTAssertEqual(attributes[int: "age"], 30)
    }

      func testAddAttributeSetIntoNamespace() {
        let attributes = MutableAttributes()
        let attributeSet = AttributeSet(labels: [
            "name": .string("John Doe"),
            "age": .int(30)
        ])

        let count = attributes.addAttributeSet(attributeSet, intoNamespace: "user")
        XCTAssertEqual(count, 2)
        XCTAssertEqual(attributes[string: "user.name"], "John Doe")
        XCTAssertEqual(attributes[int: "user.age"], 30)
    }

    // MARK: - Add Dictionary Tests

    func testAddDictionary() {
        let attributes = MutableAttributes()
        let dictionary: [String: AttributeValue] = [
            "name": .string("John Doe"),
            "age": .int(30)
        ]

        let count = attributes.addDictionary(dictionary)
        XCTAssertEqual(count, 2)
        XCTAssertEqual(attributes[string: "name"], "John Doe")
        XCTAssertEqual(attributes[int: "age"], 30)
    }

     func testAddDictionaryIntoNamespace() {
        let attributes = MutableAttributes()
        let dictionary: [String: AttributeValue] = [
            "name": .string("John Doe"),
            "age": .int(30)
        ]

        let count = attributes.addDictionary(dictionary, intoNamespace: "user")
        XCTAssertEqual(count, 2)
        XCTAssertEqual(attributes[string: "user.name"], "John Doe")
        XCTAssertEqual(attributes[int: "user.age"], 30)
    }

    // MARK: - Description Tests

    func testDescription() {
        let attributes = MutableAttributes()
        attributes[string: "name"] = "John Doe"
        attributes[int: "age"] = 30
        attributes[bool: "active"] = true

        let description = attributes.description
        XCTAssertTrue(description.contains("name: \"John Doe\""))
        XCTAssertTrue(description.contains("age: 30"))
        XCTAssertTrue(description.contains("active: true"))
    }
}
