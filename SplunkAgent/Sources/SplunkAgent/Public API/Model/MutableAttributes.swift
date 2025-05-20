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

public class MutableAttributes {
    fileprivate var attributes: ThreadSafeDictionary<String, AttributeValue>

    // MARK: - Initialize

    public init() {
        attributes = ThreadSafeDictionary<String, AttributeValue>()
    }

    public init(dictionary: [String: AttributeValue]) {
        attributes = ThreadSafeDictionary<String, AttributeValue>(dictionary: dictionary)
    }

    public init(attributeSet: AttributeSet) {
        attributes = ThreadSafeDictionary<String, AttributeValue>()
        addAttributeSet(attributeSet)
    }

    public required init(from decoder: Decoder) throws {
        attributes = ThreadSafeDictionary<String, AttributeValue>()
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        for key in container.allKeys {
            let value = try container.decode(AttributeValue.self, forKey: key)
            attributes[key.stringValue] = value
        }
    }
}

// Codable
extension MutableAttributes: Codable {

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        let dictionary = attributes.getAll()

        for (key, value) in dictionary {
            try container.encode(value, forKey: StringCodingKey(stringValue: key)!)
        }
    }

    // Helper for coding with string keys
    private struct StringCodingKey: CodingKey {
        var stringValue: String
        var intValue: Int?

        init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }

        init?(intValue: Int) {
            self.stringValue = String(intValue)
            self.intValue = intValue
        }
    }
}

// Equatable
extension MutableAttributes: Equatable {

    public static func == (lhs: MutableAttributes, rhs: MutableAttributes) -> Bool {
        let lhsDict = lhs.attributes.getAll()
        let rhsDict = rhs.attributes.getAll()

        // Compare dictionary sizes first for quick check
        guard lhsDict.count == rhsDict.count else {
            return false
        }

        // Compare each key-value pair
        for (key, lhsValue) in lhsDict {
            guard let rhsValue = rhsDict[key] else {
                return false
            }

            if lhsValue != rhsValue {
                return false
            }
        }

        return true
    }
}

// Subscripts
public extension MutableAttributes {

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
}

// Get and Set
public extension MutableAttributes {

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
}

// Iterative setters
public extension MutableAttributes {

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
}

// Utilities
public extension MutableAttributes {

    @discardableResult
    func remove(for key: String) -> AttributeValue? {
        return attributes.removeValue(forKey: key)
    }

    func removeAll() {
        attributes.removeAll()
    }

    func contains(key: String) -> Bool {
        return attributes.contains(key: key)
    }

    func getAll() -> [String: AttributeValue] {
        return attributes.getAll()
    }

    func getAllKeys() -> [String] {
        return attributes.allKeys()
    }

    func getAllValues() -> [AttributeValue] {
        return attributes.allValues()
    }

    func count() -> Int {
        return attributes.count()
    }

    private func getAllAsAny() -> [String: Any] {
        var result: [String: Any] = [:]
        let dictionary = attributes.getAll()

        for (key, value) in dictionary {
            result[key] = convertToAny(value)
        }

        return result
    }

    var all: [String: Any] {
        return getAllAsAny()
    }
}

// Description
public extension MutableAttributes {

    func description() -> String {
        var result = "[\n"

        let dictionaryCopy = attributes.getAll()
        for (key, value) in dictionaryCopy.sorted(by: { $0.key < $1.key }) {
            let valueDescription = attributeDescription(value)
            result += "  \(key): \(valueDescription)\n"
        }

        result += "]"
        return result
    }
}
