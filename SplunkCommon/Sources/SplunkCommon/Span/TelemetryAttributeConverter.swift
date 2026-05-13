//
/*
Copyright 2026 Splunk Inc.

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

/// Converts user-provided attribute values into OpenTelemetry attribute values.
@_spi(SplunkInternal)
public enum TelemetryAttributeConverter {

    // MARK: - Conversion

    /// Converts a dictionary of user-provided attributes into OpenTelemetry attribute values.
    ///
    /// - Parameter attributes: User-provided attribute values.
    /// - Returns: Converted OpenTelemetry attributes.
    public static func attributes(from attributes: [String: Any]?) -> [String: AttributeValue] {
        guard let attributes else {
            return [:]
        }

        return attributes.reduce(into: [:]) { convertedAttributes, element in
            convertedAttributes[element.key] = attributeValue(from: element.value)
        }
    }

    /// Converts a user-provided attribute value into an OpenTelemetry attribute value.
    ///
    /// Unsupported values are converted to their string representation to preserve existing span emission behavior.
    ///
    /// - Parameter value: User-provided attribute value.
    /// - Returns: Converted OpenTelemetry attribute value.
    public static func attributeValue(from value: Any) -> AttributeValue {
        switch value {
        case let stringValue as String:
            return .string(stringValue)

        case let intValue as Int:
            return numericAttributeValue(from: value, defaultValue: .int(intValue))

        case let doubleValue as Double:
            return numericAttributeValue(from: value, defaultValue: .double(doubleValue))

        case let boolValue as Bool:
            return .bool(boolValue)

        default:
            return collectionAttributeValue(from: value) ?? .string(String(describing: value))
        }
    }


    // MARK: - Private

    private static func collectionAttributeValue(from value: Any) -> AttributeValue? {
        if isExact(value, [String].self), let arrayValue = value as? [String] {
            return .array(AttributeArray(values: arrayValue.map { AttributeValue.string($0) }))
        }

        if isExact(value, [Bool].self), let arrayValue = value as? [Bool] {
            return .array(AttributeArray(values: arrayValue.map { AttributeValue.bool($0) }))
        }

        if isExact(value, [Int].self), let arrayValue = value as? [Int] {
            return .array(AttributeArray(values: arrayValue.map { AttributeValue.int($0) }))
        }

        if isExact(value, [Double].self), let arrayValue = value as? [Double] {
            return .array(AttributeArray(values: arrayValue.map { AttributeValue.double($0) }))
        }

        if let arrayValue = value as? [NSNumber] {
            return .array(AttributeArray(values: arrayValue.map { attributeValue(from: $0) }))
        }

        if let arrayValue = value as? [String] {
            return .array(AttributeArray(values: arrayValue.map { AttributeValue.string($0) }))
        }

        if let arrayValue = value as? [Bool] {
            return .array(AttributeArray(values: arrayValue.map { AttributeValue.bool($0) }))
        }

        if let arrayValue = value as? [Int] {
            return .array(AttributeArray(values: arrayValue.map { AttributeValue.int($0) }))
        }

        if let arrayValue = value as? [Double] {
            return .array(AttributeArray(values: arrayValue.map { AttributeValue.double($0) }))
        }

        return nil
    }

    private static func numericAttributeValue(from value: Any, defaultValue: AttributeValue) -> AttributeValue {
        guard
            !isExact(value, Int.self),
            !isExact(value, Double.self),
            let numberValue = value as? NSNumber
        else {
            return defaultValue
        }

        if CFGetTypeID(numberValue) == CFBooleanGetTypeID() {
            return .bool(numberValue.boolValue)
        }

        if CFNumberIsFloatType(numberValue) {
            return .double(numberValue.doubleValue)
        }

        return defaultValue
    }

    private static func isExact<T>(_ value: Any, _ type: T.Type) -> Bool {
        Swift.type(of: value) == type
    }
}
