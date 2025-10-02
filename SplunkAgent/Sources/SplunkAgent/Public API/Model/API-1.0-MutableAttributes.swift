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

/// A thread-safe object that provides a mutable collection of attributes for enriching telemetry data.
///
/// This class offers a dictionary-like interface for managing attributes that conform to
/// `OpenTelemetryApi.AttributeValue`. It is designed for safe use across multiple threads.
///
/// ### Usage
///
/// You can initialize an empty collection and add attributes using the typed subscripts.
/// To remove an attribute, set its value to `nil`.
///
/// ```swift
/// let attributes = MutableAttributes()
/// attributes[string: "user.name"] = "Alice"
/// attributes[int: "login.count"] = 5
/// attributes[bool: "is.subscribed"] = true
///
/// // Removes the 'is.subscribed' attribute.
/// attributes[bool: "is.subscribed"] = nil
/// ```
public class MutableAttributes {

    // MARK: - Private

    /// The underlying thread-safe storage for attributes.
    var attributes: ThreadSafeDictionary<String, AttributeValue>


    // MARK: - Initialize

    /// Initializes an empty collection of attributes.
    public init() {
        attributes = ThreadSafeDictionary<String, AttributeValue>()
    }

    /// Initializes the collection with attributes from a given dictionary.
    /// - Parameter dictionary: A dictionary of key-value pairs to add to the collection.
    public init(dictionary: [String: AttributeValue]) {
        attributes = ThreadSafeDictionary<String, AttributeValue>(dictionary: dictionary)
    }

    /// Initializes the collection with attributes from a given `AttributeSet`.
    /// - Parameter attributeSet: An `AttributeSet` whose labels will be added to the collection.
    public init(attributeSet: AttributeSet) {
        attributes = ThreadSafeDictionary<String, AttributeValue>()
        addAttributeSet(attributeSet)
    }

    /// Initializes the collection by decoding from a `Decoder`.
    ///
    /// This initializer is used to conform to the `Decodable` protocol.
    ///
    /// - Throws: An error if decoding fails.
    public required init(from decoder: Decoder) throws {
        attributes = ThreadSafeDictionary<String, AttributeValue>()
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        for key in container.allKeys {
            let value = try container.decode(AttributeValue.self, forKey: key)
            attributes[key.stringValue] = value
        }
    }
}

extension MutableAttributes {

    // MARK: - Subscripts

    public subscript(key: String) -> AttributeValue? {
        get {
            attributes[key]
        }
        set {
            if let newValue {
                attributes[key] = newValue
            }
            else {
                attributes.removeValue(forKey: key)
            }
        }
    }

    public subscript(string key: String) -> String? {
        get {
            if case let .string(string) = attributes[key] {
                return string
            }
            return nil
        }
        set {
            if let newValue {
                attributes[key] = AttributeValue.string(newValue)
            }
            else {
                attributes.removeValue(forKey: key)
            }
        }
    }

    public subscript(bool key: String) -> Bool? {
        get {
            if case let .bool(bool) = attributes[key] {
                return bool
            }
            return nil
        }
        set {
            if let newValue {
                attributes[key] = AttributeValue.bool(newValue)
            }
            else {
                attributes.removeValue(forKey: key)
            }
        }
    }

    public subscript(int key: String) -> Int? {
        get {
            if case let .int(int) = attributes[key] {
                return int
            }
            return nil
        }
        set {
            if let newValue {
                attributes[key] = AttributeValue.int(newValue)
            }
            else {
                attributes.removeValue(forKey: key)
            }
        }
    }

    public subscript(double key: String) -> Double? {
        get {
            if case let .double(double) = attributes[key] {
                return double
            }
            return nil
        }
        set {
            if let newValue {
                attributes[key] = AttributeValue.double(newValue)
            }
            else {
                attributes.removeValue(forKey: key)
            }
        }
    }

    public subscript(array key: String) -> AttributeArray? {
        get {
            if case let .array(array) = attributes[key] {
                return array
            }
            return nil
        }
        set {
            if let newValue {
                attributes[key] = AttributeValue.array(newValue)
            }
            else {
                attributes.removeValue(forKey: key)
            }
        }
    }

    public subscript(set key: String) -> AttributeSet? {
        get {
            if case let .set(attributeSet) = attributes[key] {
                return attributeSet
            }
            return nil
        }
        set {
            if let newValue {
                attributes[key] = AttributeValue.set(newValue)
            }
            else {
                attributes.removeValue(forKey: key)
            }
        }
    }
}

extension MutableAttributes {

    // MARK: - Getters and setters

    public func getValue(for key: String) -> AttributeValue? {
        attributes[key]
    }

    public func getString(for key: String) -> String? {
        if case let .string(string) = attributes[key] {
            return string
        }
        return nil
    }

    public func getBool(for key: String) -> Bool? {
        if case let .bool(bool) = attributes[key] {
            return bool
        }
        return nil
    }

    public func getInt(for key: String) -> Int? {
        if case let .int(int) = attributes[key] {
            return int
        }
        return nil
    }

    public func getDouble(for key: String) -> Double? {
        if case let .double(double) = attributes[key] {
            return double
        }
        return nil
    }

    public func getArray(for key: String) -> AttributeArray? {
        if case let .array(array) = attributes[key] {
            return array
        }
        return nil
    }

    public func getSet(for key: String) -> AttributeSet? {
        if case let .set(attributeSet) = attributes[key] {
            return attributeSet
        }
        return nil
    }

    public func setValue(_ value: AttributeValue, for key: String) {
        attributes[key] = value
    }

    public func setString(_ string: String, for key: String) {
        attributes[key] = AttributeValue.string(string)
    }

    public func setBool(_ bool: Bool, for key: String) {
        attributes[key] = AttributeValue.bool(bool)
    }

    public func setInt(_ int: Int, for key: String) {
        attributes[key] = AttributeValue.int(int)
    }

    public func setDouble(_ double: Double, for key: String) {
        attributes[key] = AttributeValue.double(double)
    }

    public func setArray(_ array: AttributeArray, for key: String) {
        attributes[key] = AttributeValue.array(array)
    }

    public func setSet(_ attributeSet: AttributeSet, for key: String) {
        attributes[key] = AttributeValue.set(attributeSet)
    }
}

extension MutableAttributes {

    // MARK: - Iterative setters

    @discardableResult
    public func addDictionary(_ dictionary: [String: AttributeValue]) -> Int {
        var count = 0
        for (key, value) in dictionary {
            attributes[key] = value
            count += 1
        }
        return count
    }

    @discardableResult
    public func addDictionary(_ dictionary: [String: AttributeValue], intoNamespace namespace: String) -> Int {
        var count = 0
        for (key, value) in dictionary {
            let namespaceKey = "\(namespace).\(key)"
            attributes[namespaceKey] = value
            count += 1
        }
        return count
    }

    @discardableResult
    public func addAttributeSet(_ attributeSet: AttributeSet) -> Int {
        var count = 0
        for (key, value) in attributeSet.labels {
            attributes[key] = value
            count += 1
        }
        return count
    }

    @discardableResult
    public func addAttributeSet(_ attributeSet: AttributeSet, intoNamespace namespace: String) -> Int {
        var count = 0
        for (key, value) in attributeSet.labels {
            let namespaceKey = "\(namespace).\(key)"
            attributes[namespaceKey] = value
            count += 1
        }
        return count
    }
}

extension MutableAttributes {

    // MARK: - Utilities

    @discardableResult
    public func remove(for key: String) -> AttributeValue? {
        attributes.removeValue(forKey: key)
    }

    public func removeAll() {
        attributes.removeAll()
    }

    public func contains(key: String) -> Bool {
        attributes.contains(key: key)
    }

    public func getAll() -> [String: AttributeValue] {
        attributes.getAll()
    }

    public func getAllKeys() -> [String] {
        attributes.allKeys()
    }

    public func getAllValues() -> [AttributeValue] {
        attributes.allValues()
    }

    public func count() -> Int {
        attributes.count()
    }

    private func getAllAsAny() -> [String: Any] {
        var result: [String: Any] = [:]
        let dictionary = attributes.getAll()

        for (key, value) in dictionary {
            result[key] = convertToAny(value)
        }

        return result
    }

    public var all: [String: Any] {
        getAllAsAny()
    }
}

extension MutableAttributes: CustomStringConvertible {

    // MARK: - Description

    /// A human-readable description of the attributes, sorted by key.
    public var description: String {
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
