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

/// A thread-safe, mutable collection of attributes for enriching telemetry data.
///
/// This class provides a dictionary-like interface for managing attributes that conform to
/// `OpenTelemetryApi.AttributeValue`. It is designed to be used across multiple threads safely.
///
/// ### Usage ###
///
/// You can initialize an empty collection and add attributes using typed subscripts:
///
/// ```
/// let attributes = MutableAttributes()
/// attributes[string: "user.name"] = "Alice"
/// attributes[int: "login.count"] = 5
/// attributes[bool: "is.subscribed"] = true
///
/// // To remove an attribute, set its value to nil
/// attributes[bool: "is.subscribed"] = nil
/// ```
public class MutableAttributes {

    // MARK: - Private

    // The underlying thread-safe dictionary that stores the attributes.
    var attributes: ThreadSafeDictionary<String, AttributeValue>


    // MARK: - Initialize

    /// Initializes an empty collection of attributes.
    public init() {
        attributes = ThreadSafeDictionary<String, AttributeValue>()
    }

    /// Initializes the collection with attributes from a dictionary.
    /// - Parameter dictionary: A dictionary of `AttributeValue` items to add.
    public init(dictionary: [String: AttributeValue]) {
        attributes = ThreadSafeDictionary<String, AttributeValue>(dictionary: dictionary)
    }

    /// Initializes the collection with attributes from an `AttributeSet`.
    /// - Parameter attributeSet: An `AttributeSet` to copy attributes from.
    public init(attributeSet: AttributeSet) {
        attributes = ThreadSafeDictionary<String, AttributeValue>()
        addAttributeSet(attributeSet)
    }

    /// Initializes the collection by decoding from a `Decoder`.
    public required init(from decoder: Decoder) throws {
        attributes = ThreadSafeDictionary<String, AttributeValue>()
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        for key in container.allKeys {
            let value = try container.decode(AttributeValue.self, forKey: key)
            attributes[key.stringValue] = value
        }
    }
}

public extension MutableAttributes {

    // MARK: - Subscripts

    /// Accesses the `AttributeValue` for the given key.
    ///
    /// Setting a value to `nil` removes the key-value pair.
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

    /// Accesses the `String` value for the given key.
    ///
    /// Returns `nil` if the key is not found or the value is not a string.
    /// Setting a value to `nil` removes the key-value pair.
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

    /// Accesses the `Bool` value for the given key.
    ///
    /// Returns `nil` if the key is not found or the value is not a boolean.
    /// Setting a value to `nil` removes the key-value pair.
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

    /// Accesses the `Int` value for the given key.
    ///
    /// Returns `nil` if the key is not found or the value is not an integer.
    /// Setting a value to `nil` removes the key-value pair.
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

    /// Accesses the `Double` value for the given key.
    ///
    /// Returns `nil` if the key is not found or the value is not a double.
    /// Setting a value to `nil` removes the key-value pair.
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

    /// Accesses the `AttributeArray` value for the given key.
    ///
    /// Returns `nil` if the key is not found or the value is not an array.
    /// Setting a value to `nil` removes the key-value pair.
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

    /// Accesses the `AttributeSet` value for the given key.
    ///
    /// Returns `nil` if the key is not found or the value is not a set.
    /// Setting a value to `nil` removes the key-value pair.
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

public extension MutableAttributes {

    // MARK: - Getters and setters

    /// Returns the `AttributeValue` for the given key.
    func getValue(for key: String) -> AttributeValue? {
        return attributes[key]
    }

    /// Returns the `String` value for the given key, or `nil` if the key is not found or the value is not a string.
    func getString(for key: String) -> String? {
        if case let .string(string) = attributes[key] {
            return string
        }
        return nil
    }

    /// Returns the `Bool` value for the given key, or `nil` if the key is not found or the value is not a boolean.
    func getBool(for key: String) -> Bool? {
        if case let .bool(bool) = attributes[key] {
            return bool
        }
        return nil
    }

    /// Returns the `Int` value for the given key, or `nil` if the key is not found or the value is not an integer.
    func getInt(for key: String) -> Int? {
        if case let .int(int) = attributes[key] {
            return int
        }
        return nil
    }

    /// Returns the `Double` value for the given key, or `nil` if the key is not found or the value is not a double.
    func getDouble(for key: String) -> Double? {
        if case let .double(double) = attributes[key] {
            return double
        }
        return nil
    }

    /// Returns the `AttributeArray` for the given key, or `nil` if the key is not found or the value is not an array.
    func getArray(for key: String) -> AttributeArray? {
        if case let .array(array) = attributes[key] {
            return array
        }
        return nil
    }

    /// Returns the `AttributeSet` for the given key, or `nil` if the key is not found or the value is not a set.
    func getSet(for key: String) -> AttributeSet? {
        if case let .set(attributeSet) = attributes[key] {
            return attributeSet
        }
        return nil
    }

    /// Sets or updates the `AttributeValue` for the given key.
    func setValue(_ value: AttributeValue, for key: String) {
        attributes[key] = value
    }

    /// Sets or updates a `String` value for the given key.
    func setString(_ string: String, for key: String) {
        attributes[key] = AttributeValue.string(string)
    }

    /// Sets or updates a `Bool` value for the given key.
    func setBool(_ bool: Bool, for key: String) {
        attributes[key] = AttributeValue.bool(bool)
    }

    /// Sets or updates an `Int` value for the given key.
    func setInt(_ int: Int, for key: String) {
        attributes[key] = AttributeValue.int(int)
    }

    /// Sets or updates a `Double` value for the given key.
    func setDouble(_ double: Double, for key: String) {
        attributes[key] = AttributeValue.double(double)
    }

    /// Sets or updates an `AttributeArray` value for the given key.
    func setArray(_ array: AttributeArray, for key: String) {
        attributes[key] = AttributeValue.array(array)
    }

    /// Sets or updates an `AttributeSet` value for the given key.
    func setSet(_ attributeSet: AttributeSet, for key: String) {
        attributes[key] = AttributeValue.set(attributeSet)
    }
}

public extension MutableAttributes {

    // MARK: - Iterative setters

    /// Adds or updates attributes from a given dictionary.
    /// - Parameter dictionary: A dictionary of attributes to add.
    /// - Returns: The number of attributes added or updated.
    @discardableResult
    func addDictionary(_ dictionary: [String: AttributeValue]) -> Int {
        var count = 0
        for (key, value) in dictionary {
            attributes[key] = value
            count += 1
        }
        return count
    }

    /// Adds or updates attributes from a dictionary, prefixing each key with a namespace.
    /// - Parameter dictionary: A dictionary of attributes to add.
    /// - Parameter namespace: A string to prepend to each key, followed by a dot.
    /// - Returns: The number of attributes added or updated.
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

    /// Adds or updates attributes from a given `AttributeSet`.
    /// - Parameter attributeSet: An `AttributeSet` to copy attributes from.
    /// - Returns: The number of attributes added or updated.
    @discardableResult
    func addAttributeSet(_ attributeSet: AttributeSet) -> Int {
        var count = 0
        for (key, value) in attributeSet.labels {
            attributes[key] = value
            count += 1
        }
        return count
    }

    /// Adds or updates attributes from an `AttributeSet`, prefixing each key with a namespace.
    /// - Parameter attributeSet: An `AttributeSet` to copy attributes from.
    /// - Parameter namespace: A string to prepend to each key, followed by a dot.
    /// - Returns: The number of attributes added or updated.
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

public extension MutableAttributes {

    // MARK: - Utilities

    /// Removes the attribute for the given key.
    /// - Parameter key: The key of the attribute to remove.
    /// - Returns: The value that was removed, or `nil` if the key was not present.
    @discardableResult
    func remove(for key: String) -> AttributeValue? {
        return attributes.removeValue(forKey: key)
    }

    /// Removes all attributes from the collection.
    func removeAll() {
        attributes.removeAll()
    }

    /// Returns a Boolean value indicating whether the collection contains an attribute for the given key.
    /// - Parameter key: The key to check for.
    /// - Returns: `true` if an attribute with the specified key exists, otherwise `false`.
    func contains(key: String) -> Bool {
        return attributes.contains(key: key)
    }

    /// Returns a dictionary containing all attributes.
    func getAll() -> [String: AttributeValue] {
        return attributes.getAll()
    }

    /// Returns an array of all attribute keys.
    func getAllKeys() -> [String] {
        return attributes.allKeys()
    }

    /// Returns an array of all attribute values.
    func getAllValues() -> [AttributeValue] {
        return attributes.allValues()
    }

    /// Returns the number of attributes in the collection.
    func count() -> Int {
        return attributes.count()
    }

    // Converts the internal `AttributeValue` dictionary to a `[String: Any]` dictionary.
    private func getAllAsAny() -> [String: Any] {
        var result: [String: Any] = [:]
        let dictionary = attributes.getAll()

        for (key, value) in dictionary {
            result[key] = convertToAny(value)
        }

        return result
    }

    /// A dictionary containing all attributes, with values converted to `Any`.
    var all: [String: Any] {
        return getAllAsAny()
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