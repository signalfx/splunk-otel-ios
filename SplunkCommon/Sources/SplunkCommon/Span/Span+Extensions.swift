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

/// Internal extensions to the OpenTelemetry Span protocol
@_spi(SplunkInternal)
public extension Span {

    /// Clears the existing value for a key and sets a new value atomically.
    /// This is useful for ensuring clean attribute updates without leftover values.
    ///
    /// - Parameters:
    ///   - key: The attribute key to clear and set
    ///   - value: The new value to set for the key
    func clearAndSetAttribute(key: String, value: AttributeValue) {
        // First clear the existing value by setting it to nil
        setAttribute(key: key, value: nil as AttributeValue?)

        // Then set the new value
        setAttribute(key: key, value: value)
    }

    /// Clears the existing value for a key and sets a new value atomically.
    /// This is a convenience method that accepts Any and converts it to AttributeValue.
    ///
    /// - Parameters:
    ///   - key: The attribute key to clear and set
    ///   - value: The new value to set for the key (will be converted to AttributeValue)
    func clearAndSetAttribute(key: String, value: Any) {
        // Convert the Any value to AttributeValue based on its type
        let attributeValue: AttributeValue

        switch value {
        case let stringValue as String:
            attributeValue = .string(stringValue)
        case let intValue as Int:
            attributeValue = .int(intValue)
        case let doubleValue as Double:
            attributeValue = .double(doubleValue)
        case let boolValue as Bool:
            attributeValue = .bool(boolValue)
        case let arrayValue as [String]:
            attributeValue = .array(AttributeArray(values: arrayValue.map { AttributeValue.string($0) }))
        case let arrayValue as [Int]:
            attributeValue = .array(AttributeArray(values: arrayValue.map { AttributeValue.int($0) }))
        case let arrayValue as [Double]:
            attributeValue = .array(AttributeArray(values: arrayValue.map { AttributeValue.double($0) }))
        case let arrayValue as [Bool]:
            attributeValue = .array(AttributeArray(values: arrayValue.map { AttributeValue.bool($0) }))
        default:
            // For unsupported types, convert to string representation
            attributeValue = .string(String(describing: value))
        }

        clearAndSetAttribute(key: key, value: attributeValue)
    }

    // MARK: - SemanticAttributes Convenience Methods

    /// Clears the existing value for a semantic attribute key and sets a new value atomically.
    /// This is useful for ensuring clean attribute updates without leftover values.
    ///
    /// - Parameters:
    ///   - key: The semantic attribute key to clear and set
    ///   - value: The new value to set for the key
    func clearAndSetAttribute(key: SemanticAttributes, value: AttributeValue) {
        clearAndSetAttribute(key: key.rawValue, value: value)
    }

    /// Clears the existing value for a semantic attribute key and sets a new value atomically.
    /// This is a convenience method that accepts Any and converts it to AttributeValue.
    ///
    /// - Parameters:
    ///   - key: The semantic attribute key to clear and set
    ///   - value: The new value to set for the key (will be converted to AttributeValue)
    func clearAndSetAttribute(key: SemanticAttributes, value: Any) {
        clearAndSetAttribute(key: key.rawValue, value: value)
    }
}
