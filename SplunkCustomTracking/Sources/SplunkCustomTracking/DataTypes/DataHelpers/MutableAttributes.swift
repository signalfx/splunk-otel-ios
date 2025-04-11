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


// MARK: - SplunkAttribute: Protocol for general attribute behavior
protocol SplunkAttribute {
    var description: String { get }
}


// MARK: - Extension of base types for SplunkAttribute conformance
extension String: SplunkAttribute {}
extension Int: SplunkAttribute {}
extension Double: SplunkAttribute {}


// MARK: AttributeContainer: Protocol for common attribute operations
protocol AttributeContainer {


    // MARK: - Associated types

    // Allows T to stand in for any type having SplunkAttribute conformance
    associatedtype T: SplunkAttribute


    // MARK: - Protocol required functions

    // Stores SplunkAttribute attributes in a key-value format
    var attributes: [String: T] { get set }

    // Adds an attribute or updates an existing one
    mutating func setAttribute(for key: String, value: T)

    // Retrieves a specific attribute
    func getAttribute(for key: String) -> T?

    // Returns all attributes to support operations like data output
    func listAttributes() -> [String: T]

    // Removes a specific attribute
    mutating func remove(key: String)

    // Clears all attributes to reset the storage
    mutating func removeAll()

    // Replaces existing attributes with new ones for batch updates
    mutating func setAll(newAttributes: [String: T])

    // Applies a transformation using the Mapping pattern
    func apply<U: SplunkAttribute>(mappingClosure: (String, T) -> U) -> MutableAttributes<U> {

    // Modifies attributes in place using the Mutator pattern
    mutating func apply(mutatingClosure: (String, inout T) -> Void)
}


// MARK: - AttributeContainer: Default implementations for AttributeContainer
extension AttributeContainer {


    // MARK: - Protocol required function default implementations

    func getAttribute(for key: String) -> T? {
        return attributes[key]
    }

    func listAttributes() -> [String: T] {
        return attributes
    }

    mutating func remove(key: String) {
        apply(mutatingClosure: { k, _ in
            if k == key {
                attributes[k] = nil
            }
        })
    }

    mutating func removeAll() {
        apply(mutatingClosure: { k, _ in
            attributes[k] = nil
        })
    }

    mutating func setAll(newAttributes: [String: T]) {
        apply(mutatingClosure: { k, _ in
            if let newValue = newAttributes[k] {
                attributes[k] = newValue
            }
        })
    }


    // MARK: - Mapping pattern to return transformed attributes

    func apply<U: SplunkAttribute>(mappingClosure: (String, T) -> U) -> MutableAttributes<U> {
        var mappedAttributes = MutableAttributes<U>()
        for (key, value) in listAttributes() {
            let newValue = mappingClosure(key, value)
            mappedAttributes.setAttribute(for: key, value: newValue)
        }
        return mappedAttributes
    }


    // MARK: - Mutator Pattern: Modify attributes in place

    mutating func apply(mutatingClosure: (String, inout T) -> Void) {
        update { attributes in
            for (key, var value) in attributes {
                mutatingClosure(key, &value)
                attributes[key] = value
            }
        }
    }
}


// MARK: - MutableAttributes: Base struct for managing attributes
struct MutableAttributes<T: SplunkAttribute>: AttributeContainer {
    var attributes: [String: T] = [:]

    mutating func setAttribute(for key: String, value: T) {
        attributes[key] = value
    }
}


// MARK: - LengthEnforcable: Protocol for enforcing length constraints
protocol LengthEnforcable: AttributeContainer {
    var maxKeyLength: Int { get }
    var maxValueLength: Int { get }
    mutating func setAttribute(for key: String, value: T) -> Bool
}


// MARK: - LengthEnforcable: Extension to provide default length constraints
extension LengthEnforcable {
    var maxKeyLength: Int { 1024 }
    var maxValueLength: Int { 2048 }
}


// MARK: - ConstrainedAttributes: Struct for managing attributes with length constraints
struct ConstrainedAttributes<T: SplunkAttribute>: LengthEnforcable {
    var attributes = MutableAttributes<T>().attributes


    // MARK: - Constrained setAttribute that checks the length of its keys and values

    mutating func setAttribute(for key: String, value: T) -> Bool {
        guard key.count <= maxKeyLength, value.description.count <= maxValueLength else {
            print("Invalid key or value length.")
            return false
        }
        attributes[key] = value
        return true
    }
}
