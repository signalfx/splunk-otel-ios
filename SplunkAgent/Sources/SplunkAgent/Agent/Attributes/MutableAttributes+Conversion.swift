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
internal import SplunkCommon

extension MutableAttributes {

    // MARK: - Type Conversion

    // swiftlint:disable cyclomatic_complexity
    func convertToAny(_ value: AttributeValue) -> Any {
        switch value {
        case let .string(string):
            return string
        case let .bool(bool):
            return bool
        case let .int(int):
            return int
        case let .double(double):
            return double
        case let .array(array):
            return array.values.map { convertToAny($0) }
        case let .stringArray(stringArray):
            return stringArray
        case let .boolArray(boolArray):
            return boolArray
        case let .intArray(intArray):
            return intArray
        case let .doubleArray(doubleArray):
            return doubleArray
        case let .set(attributeSet):
            var result: [String: Any] = [:]
            for (key, value) in attributeSet.labels {
                result[key] = convertToAny(value)
            }
            return result
        }
    }


    // MARK: - Description

    func attributeDescription(_ value: AttributeValue) -> String {
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
    } // swiftlint:enable cyclomatic_complexity

    // Convert Attribute values to target type using provided closure
    // - Parameters:
    //   - targetType: Desired type for the values
    //   - transform: Closure to convert `AttributeValue` to an optional target type
    //     note: specific to OpenTelemetryApi.AttributeValue source type
    // - Returns: [String: T] with converted values, omitting non-convertible ones
    func converted<T>(
        to targetType: T.Type,
        using transform: (AttributeValue) -> T?
    ) -> [String: T] {

        let sourceAttributes = getAll()

        if sourceAttributes.isEmpty {
            return [:]
        }

        var convertedAttributes: [String: T] = Dictionary(minimumCapacity: sourceAttributes.count)

        for (key, otelValue) in sourceAttributes {
            // Caller provides the `transform` closure
            // only add items we can successfully transform
            if let convertedValue = transform(otelValue) {
                convertedAttributes[key] = convertedValue
            }
        }
        return convertedAttributes
    }

    private static let convertToEventAttributeValue: (AttributeValue) -> EventAttributeValue? = { attributeValue in
        switch attributeValue {
        case let .string(value):
            return EventAttributeValue.string(value)
        case let .int(value):
            return EventAttributeValue.int(value)
        case let .double(value):
            return EventAttributeValue.double(value)
        case .array:
            return nil
        case .set:
            return nil
        case let .bool(boolValue):
            return boolValue ? EventAttributeValue.string("true") : EventAttributeValue.string("false")
        case .stringArray, .boolArray, .intArray, .doubleArray:
            return nil
        }
    }

    // Convert Attributes to `[String: EventAttributeValue]`
    // - Parameters: none
    // - Returns: [String: EventAttributeValue] omitting non-convertible elements
    func toEventAttributes() -> [String: EventAttributeValue] {
        return converted(to: EventAttributeValue.self, using: MutableAttributes.convertToEventAttributeValue)
    }
}


// MARK: - Initialize from Dictionary / NSDictionary

extension MutableAttributes {

    // Make a `MutableAttributes` instance from a `Dictionary`
    convenience init(from dictionary: [String: Any], maxDepth: Int = 20) {
        self.init()

        let attributes = Self._convertDictionaryToAttributes(dictionary, maxDepth: maxDepth)

        for (key, value) in attributes {
            self[key] = value
        }
    }

    // Make a `MutableAttributes` instance from an `NSDictionary`
    convenience init(from nsDictionary: NSDictionary, maxDepth: Int = 20) {
        // Safely bridge `NSDictionary` to `[String: Any]`
        let dictionary = nsDictionary as? [String: Any] ?? [:]
        self.init(from: dictionary, maxDepth: maxDepth)
    }

    // Convert a dictionary to `[String: AttributeValue]`, enforcing depth constraints
    private static func _convertDictionaryToAttributes(
        _ dictionary: [String: Any],
        maxDepth: Int,
        currentDepth: Int = 0
    ) -> [String: AttributeValue] {
        // Enforce maximum depth
        if currentDepth > maxDepth {
            return [:]
        }

        // Convert each key-value pair into AttributeValue
        var result: [String: AttributeValue] = [:]
        for (key, value) in dictionary {
            if let attributeValue = Self._convertValueToAttribute(value, maxDepth: maxDepth, currentDepth: currentDepth + 1) {
                result[key] = attributeValue
            }
        }
        return result
    }

    // Convert a value to an `AttributeValue`, enforcing depth constraints
    private static func _convertValueToAttribute(
        _ value: Any,
        maxDepth: Int,
        currentDepth: Int
    ) -> AttributeValue? {
        // Enforce maximum depth
        if currentDepth > maxDepth {
            return nil
        }

        switch value {
        case let stringValue as String:
            return .string(stringValue)
        case let boolValue as Bool:
            return .bool(boolValue)
        case let intValue as Int:
            return .int(intValue)
        case let doubleValue as Double:
            return .double(doubleValue)
        case let arrayValue as [Any]:
            // Enforce depth for nested arrays
            let convertedArray = arrayValue.compactMap { element in
                _convertValueToAttribute(element, maxDepth: maxDepth, currentDepth: currentDepth + 1)
            }
            return .array(AttributeArray(values: convertedArray))
        case let dictValue as [String: Any]:
            // Delegate to the dictionary helper for nested dictionaries
            let convertedDict = _convertDictionaryToAttributes(dictValue, maxDepth: maxDepth, currentDepth: currentDepth + 1)
            return .set(AttributeSet(labels: convertedDict))
        case let nsDictValue as NSDictionary:
            // Convert `NSDictionary` to `[String: Any]` and handle it
            let swiftDictValue = nsDictValue as? [String: Any] ?? [:]
            let convertedDict = _convertDictionaryToAttributes(swiftDictValue, maxDepth: maxDepth, currentDepth: currentDepth + 1)
            return .set(AttributeSet(labels: convertedDict))
        default:
            // Unsupported types are skipped
            return nil
        }
    }
}
