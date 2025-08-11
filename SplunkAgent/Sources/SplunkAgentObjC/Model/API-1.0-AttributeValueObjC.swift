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

/// Object wrapper for basic attribute types used in OpenTelemetry.
///
/// The supported value types are `NSString`, `NSInteger`, `BOOL`, and `double`.
@objc(SPLKAttributeValue) @objcMembers
public final class AttributeValueObjC: NSObject {

    // MARK: - Private

    let value: Any


    // MARK: - Public

    /// Identifies the type of attribute value held.
    public let type: AttributeValueTypeObjC


    // MARK: - Initialization

    /// Initializes a new instance of an attribute for a `BOOL` type value.
    ///
    /// - Parameter bool: The value for the new attribute.
    public convenience init(bool: Bool) {
        self.init(boolNumber: NSNumber(value: bool))
    }

    /// Initializes a new instance of an attribute for a `BOOL` type value, encapsulated as a `NSNumber`.
    ///
    /// - Parameter boolNumber: The value for the new attribute, encapsulated as a `NSNumber`.
    public init(boolNumber: NSNumber) {
        value = boolNumber
        type = .bool
    }


    /// Initializes a new instance of an attribute for a `double` type value.
    ///
    /// - Parameter double: The value for the new attribute.
    public convenience init(double: Double) {
        self.init(doubleNumber: NSNumber(value: double))
    }

    /// Initializes a new instance of an attribute for a `double` type value, encapsulated as a `NSNumber`.
    ///
    /// - Parameter doubleNumber: The value for the new attribute, encapsulated as a `NSNumber`.
    public init(doubleNumber: NSNumber) {
        value = doubleNumber
        type = .double
    }


    /// Initializes a new instance of an attribute for a `NSInteger` type value.
    ///
    /// - Parameter integer: The value for the new attribute.
    public convenience init(integer: Int) {
        self.init(integerNumber: NSNumber(value: integer))
    }

    /// Initializes a new instance of an attribute for a `NSInteger` type value, encapsulated as a `NSNumber`.
    ///
    /// - Parameter integerNumber: The value for the new attribute, encapsulated as a `NSNumber`.
    public init(integerNumber: NSNumber) {
        value = integerNumber
        type = .integer
    }


    /// Initializes a new instance of an attribute for an `NSString` type value.
    ///
    /// - Parameter string: A `NSString` with value for the new attribute.
    public init(string: String) {
        value = string
        type = .string
    }


    // MARK: - Typed getters

    /// The value of the `BOOL` attribute, encapsulated as a `NSNumber`.
    ///
    /// If the attribute has not been initialized with a `BOOL`, it will return `nil`.
    public var asBoolNumber: NSNumber? {
        guard type == .bool else {
            return nil
        }

        return value as? NSNumber
    }

    /// The value of the `double` attribute, encapsulated as a `NSNumber`.
    ///
    /// If the attribute has not been initialized with a `double`, it will return `nil`.
    public var asDoubleNumber: NSNumber? {
        guard type == .double else {
            return nil
        }

        return value as? NSNumber
    }

    /// The value of the `NSInteger` attribute, encapsulated as a `NSNumber`.
    ///
    /// If the attribute has not been initialized with a `NSInteger`, it will return `nil`.
    public var asIntegerNumber: NSNumber? {
        guard type == .integer else {
            return nil
        }

        return value as? NSNumber
    }

    /// The value of the `NSString` attribute.
    ///
    /// If the attribute has not been initialized with a `NSString`, it will return `nil`.
    public var asString: NSString? {
        return value as? NSString
    }


    // MARK: - Factory methods

    /// Creates a new instance of an attribute for a `BOOL` type value.
    ///
    /// - Parameter bool: The value for the new attribute.
    ///
    /// - Returns: A new `BOOL` attribute, encapsulated as a `NSNumber`.
    public static func attributeWithBool(_ bool: Bool) -> AttributeValueObjC {
        return .init(bool: bool)
    }

    /// Creates a new instance of an attribute for a `double` type value.
    ///
    /// - Parameter double: The value for the new attribute.
    ///
    /// - Returns: A new `double` attribute, encapsulated as a `NSNumber`.
    public static func attributeWithDouble(_ double: Double) -> AttributeValueObjC {
        return .init(double: double)
    }

    /// Creates a new instance of an attribute for a `NSInteger` type value.
    ///
    /// - Parameter integer: The value for the new attribute.
    ///
    /// - Returns: A new `NSInteger` attribute, encapsulated as a `NSNumber`.
    public static func attributeWithInteger(_ integer: Int) -> AttributeValueObjC {
        return .init(integer: integer)
    }

    /// Creates a new instance of an attribute for a `NSString` type value.
    ///
    /// - Parameter string: A `NSString` with value for the new attribute.
    ///
    /// - Returns: A new `NSString` attribute.
    public static func attributeWithString(_ string: String) -> AttributeValueObjC {
        return .init(string: string)
    }
}


extension AttributeValueObjC {

    // MARK: - Computed properties

    var otelAttributeValue: AttributeValue? {
        switch type {
        case .bool:
            if let boolValue = asBoolNumber?.boolValue {
                return AttributeValue.bool(boolValue)
            }

        case .double:
            if let doubleValue = asDoubleNumber?.doubleValue {
                return AttributeValue.double(doubleValue)
            }

        case .integer:
            if let intValue = asIntegerNumber?.intValue {
                return AttributeValue.int(intValue)
            }

        case .string:
            if let stringValue = asString {
                return AttributeValue.string(String(stringValue))
            }
        }

        return nil
    }


    // MARK: - Conversion init

    convenience init?(with otelAttributeValue: AttributeValue) {
        switch otelAttributeValue {
        case let .bool(bool):
            self.init(bool: bool)

        case let .double(double):
            self.init(double: double)

        case let .int(int):
            self.init(integer: int)

        case let .string(string):
            self.init(string: string)

        default:
            return nil
        }
    }
}


public extension AttributeValueObjC {

    // MARK: - String convertible

    /// A human-readable string representation of the `SPLKAttributeValue` instance.
    override var description: String {
        switch type {
        case .bool:
            if let boolValue = asBoolNumber?.boolValue {
                return String(describing: boolValue)
            }

        case .double:
            if let doubleValue = asDoubleNumber?.doubleValue {
                return String(describing: doubleValue)
            }

        case .integer:
            if let integerValue = asIntegerNumber?.intValue {
                return String(describing: integerValue)
            }

        case .string:
            if let stringValue = value as? String {
                return stringValue.description
            }
        }

        return "unknown"
    }

    /// A string representation of an `SPLKAttributeValue` instance intended for diagnostic output.
    override var debugDescription: String {
        return "SPLKAttributeValue<\(type)>: \(description)"
    }
}
