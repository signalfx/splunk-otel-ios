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

class MutableAttributes {
    private var attributes: [String: AttributeValue]

    // MARK: - Initialize

    init() {
        attributes = [:]
    }

    init(dictionary: [String: AttributeValue]) {
        attributes = dictionary
    }

    init(attributeSet: AttributeSet) {
        attributes = [:]
        addAttributeSet(attributeSet)
    }

    // MARK: - Subscripts

    subscript(key: String) -> AttributeValue? {
        get {
            return attributes[key]
        }
        set {
            if let newValue = newValue {
                attributes[key] = newValue
            } else {
                attributes.removeValue(forKey: key)
            }
        }
    }

    subscript(string key: String) -> String? {
        get {
            if case let .string(string) = attributes[key] {
                return string
            }
            return nil
        }
        set {
            if let newValue = newValue {
                attributes[key] = AttributeValue.string(newValue)
            } else {
                attributes.removeValue(forKey: key)
            }
        }
    }

    subscript(bool key: String) -> Bool? {
        get {
            if case let .bool(bool) = attributes[key] {
                return bool
            }
            return nil
        }
        set {
            if let newValue = newValue {
                attributes[key] = AttributeValue.bool(newValue)
            } else {
                attributes.removeValue(forKey: key)
            }
        }
    }

    subscript(int key: String) -> Int? {
        get {
            if case let .int(int) = attributes[key] {
                return int
            }
            return nil
        }
        set {
            if let newValue = newValue {
                attributes[key] = AttributeValue.int(newValue)
            } else {
                attributes.removeValue(forKey: key)
            }
        }
    }

    subscript(double key: String) -> Double? {
        get {
            if case let .double(double) = attributes[key] {
                return double
            }
            return nil
        }
        set {
            if let newValue = newValue {
                attributes[key] = AttributeValue.double(newValue)
            } else {
                attributes.removeValue(forKey: key)
            }
        }
    }

    subscript(array key: String) -> AttributeArray? {
        get {
            if case let .array(array) = attributes[key] {
                return array
            }
            return nil
        }
        set {
            if let newValue = newValue {
                attributes[key] = AttributeValue.array(newValue)
            } else {
                attributes.removeValue(forKey: key)
            }
        }
    }

    subscript(set key: String) -> AttributeSet? {
        get {
            if case let .set(attributeSet) = attributes[key] {
                return attributeSet
            }
            return nil
        }
        set {
            if let newValue = newValue {
                attributes[key] = AttributeValue.set(newValue)
            } else {
                attributes.removeValue(forKey: key)
            }
        }
    }

    // MARK: - Get and Set

    func getValue(for key: String) -> AttributeValue? {
        return attributes[key]
    }

    func getString(for key: String) -> String? {
        if case let .string(string) = attributes[key] {
            return string
        }
        return nil
    }

    func getBool(for key: String) -> Bool? {
        if case let .bool(bool) = attributes[key] {
            return bool
        }
        return nil
    }

    func getInt(for key: String) -> Int? {
        if case let .int(int) = attributes[key] {
            return int
        }
        return nil
    }

    func getDouble(for key: String) -> Double? {
        if case let .double(double) = attributes[key] {
            return double
        }
        return nil
    }

    func getArray(for key: String) -> AttributeArray? {
        if case let .array(array) = attributes[key] {
            return array
        }
        return nil
    }

    func getSet(for key: String) -> AttributeSet? {
        if case let .set(attributeSet) = attributes[key] {
            return attributeSet
        }
        return nil
    }

    func setValue(_ value: AttributeValue, for key: String) {
        attributes[key] = value
    }

    func setString(_ string: String, for key: String) {
        attributes[key] = AttributeValue.string(string)
    }

    func setBool(_ bool: Bool, for key: String) {
        attributes[key] = AttributeValue.bool(bool)
    }

    func setInt(_ int: Int, for key: String) {
        attributes[key] = AttributeValue.int(int)
    }

    func setDouble(_ double: Double, for key: String) {
        attributes[key] = AttributeValue.double(double)
    }

    func setArray(_ array: AttributeArray, for key: String) {
        attributes[key] = AttributeValue.array(array)
    }

    func setSet(_ attributeSet: AttributeSet, for key: String) {
        attributes[key] = AttributeValue.set(attributeSet)
    }

    // MARK: - Iterative setters

    @discardableResult
    func addDictionary(_ dictionary: [String: AttributeValue]) -> Int {
        var count = 0
        for (key, value) in dictionary {
            attributes[key] = value
            count += 1
        }
        return count
    }

    @discardableResult
    func addDictionary(_ dictionary: [String: AttributeValue], intoNamespace namespace: String) -> Int {
        var count = 0
        for (key, value) in dictionary {
            let namespaceKey = "\(namespace).\(key)"
            attributes[namespaceKey] = value
            count += 1
        }
        return count
    }

    @discardableResult
    func addAttributeSet(_ attributeSet: AttributeSet) -> Int {
        var count = 0
        for (key, value) in attributeSet.labels {
            attributes[key] = value
            count += 1
        }
        return count
    }

    @discardableResult
    func addAttributeSet(_ attributeSet: AttributeSet, intoNamespace namespace: String) -> Int {
        var count = 0
        for (key, value) in attributeSet.labels {
            let namespaceKey = "\(namespace).\(key)"
            attributes[namespaceKey] = value
            count += 1
        }
        return count
    }

    // MARK: - Utilities

    @discardableResult
    func remove(for key: String) -> AttributeValue? {
        return attributes.removeValue(forKey: key)
    }

    func removeAll() {
        attributes.removeAll()
    }

    func contains(key: String) -> Bool {
        return attributes.keys.contains(key)
    }

    func getAll() -> [String: AttributeValue] {
        return attributes
    }

    func getAllKeys() -> [String] {
        return Array(attributes.keys)
    }

    func getAllValues() -> [AttributeValue] {
        return Array(attributes.values)
    }

    func count() -> Int {
        return attributes.count
    }

    // MARK: - Description

    func description() -> String {
        var result = "[\n"

        for (key, value) in attributes.sorted(by: { $0.key < $1.key }) {
            let valueDescription = attributeDescription(value)
            result += "  \(key): \(valueDescription)\n"
        }

        result += "]"
        return result
    }

    private func attributeDescription(_ value: AttributeValue) -> String {
        switch value {
        case let .string(string):
            return "\"\(string)\""
        case let .bool(bool):
            return bool ? "true" : "false"
        case let .int(int):
            return "\(int)"
        case let .double(double):
            return "\(double)"
        case let .array(array):
            return array.description
        case let .stringArray(stringArray):
            let arrayElements = stringArray.map { "\"\($0)\"" }.joined(separator: ", ")
            return "[\(arrayElements)]"
        case let .boolArray(boolArray):
            let arrayElements = boolArray.map { $0 ? "true" : "false" }.joined(separator: ", ")
            return "[\(arrayElements)]"
        case let .intArray(intArray):
            let arrayElements = intArray.map { "\($0)" }.joined(separator: ", ")
            return "[\(arrayElements)]"
        case let .doubleArray(doubleArray):
            let arrayElements = doubleArray.map { "\($0)" }.joined(separator: ", ")
            return "[\(arrayElements)]"
        case let .set(attributeSet):
            var elements: [String] = []
            for (key, value) in attributeSet.labels {
                elements.append("\(key): \(attributeDescription(value))")
            }
            return "{\(elements.joined(separator: ", "))}"
        }
    }
}
