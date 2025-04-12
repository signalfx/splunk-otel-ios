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


// MARK: AttributeContainer: Protocol for common attribute operations
protocol AttributeContainer {

    // MARK: - Protocol required functions

    // Stores EventAttributeValue attributes in a key-value format
    var attributes: [String: EventAttributeValue] { get set }

    // Adds an attribute or updates an existing one
    mutating func setAttribute(for key: String, value: EventAttributeValue)

    // Retrieves a specific attribute
    func getAttribute(for key: String) -> EventAttributeValue?

    // Returns all attributes to support operations like data output
    func listAttributes() -> [String: EventAttributeValue]

    // Removes a specific attribute
    mutating func remove(key: String)

    // Clears all attributes to reset the storage
    mutating func removeAll()

    // Replaces existing attributes with new ones for batch updates
    mutating func setAll(newAttributes: [String: EventAttributeValue])

    // Applies a transformation using the Mapping pattern
    func apply<U: Hashable>(mappingClosure: (String, EventAttributeValue) -> U) -> MutableAttributes

    // Modifies attributes in place using the Mutator pattern
    mutating func apply(mutatingClosure: (String, inout EventAttributeValue) -> Void)
}


// MARK: - AttributeContainer: Default implementations for AttributeContainer
extension AttributeContainer {

    // MARK: - Protocol required function default implementations

    func getAttribute(for key: String) -> EventAttributeValue? {
        return attributes[key]
    }

    func listAttributes() -> [String: EventAttributeValue] {
        return attributes
    }

    mutating func remove(key: String) {
        attributes[key] = nil
    }

    mutating func removeAll() {
        attributes.removeAll()
    }

    mutating func setAll(newAttributes: [String: EventAttributeValue]) {
        attributes = newAttributes
    }

    // MARK: - Mapping pattern to return transformed attributes

    func apply<U: Hashable>(mappingClosure: (String, EventAttributeValue) -> U) -> MutableAttributes {
        var mappedAttributes = MutableAttributes()
        for (key, value) in listAttributes() {
            let _ = mappingClosure(key, value)
            mappedAttributes.setAttribute(for: key, value: value)
        }
        return mappedAttributes
    }

    // MARK: - Mutator Pattern: Modify attributes in place

    mutating func apply(mutatingClosure: (String, inout EventAttributeValue) -> Void) {
        for (key, var value) in attributes {
            mutatingClosure(key, &value)
            attributes[key] = value
        }
    }
}


// MARK: - MutableAttributes: Base struct for managing attributes
struct MutableAttributes: AttributeContainer {
    var attributes: [String: EventAttributeValue] = [:]

    mutating func setAttribute(for key: String, value: EventAttributeValue) {
        attributes[key] = value
    }
}


// MARK: - LengthEnforcable: Protocol for enforcing length constraints
protocol LengthEnforcable: AttributeContainer {
    var maxKeyLength: Int { get }
    var maxValueLength: Int { get }
    mutating func setAttribute(for key: String, value: EventAttributeValue) -> Bool
}


// MARK: - LengthEnforcable: Extension to provide default length constraints
extension LengthEnforcable {
    var maxKeyLength: Int { 1024 }
    var maxValueLength: Int { 2048 }
}


// MARK: - ConstrainedAttributes: Struct for managing attributes with length constraints
struct ConstrainedAttributes: LengthEnforcable {
    var attributes: [String: EventAttributeValue] = [:]

    // MARK: - Constrained setAttribute that checks the length of its keys and values

    mutating func setAttribute(for key: String, value: EventAttributeValue) -> Bool {
        guard key.count <= maxKeyLength, value.description.count <= maxValueLength else {
            print("Invalid key or value length.")
            return false
        }
        attributes[key] = value
        return true
    }
}
