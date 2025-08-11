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

/// Types of currently supported values for attributes defined in OpenTelemetry.
@objc(SPLKAttributeValueType)
public enum AttributeValueTypeObjC: Int {
    /// The stored value is of the `BOOL` type.
    case bool
    
    /// The stored value is of the `double` type.
    case double
    
    /// The stored value is of the `integer` type.
    case integer
    
    /// The stored value is of the `NSString` type.
    case string
}


extension AttributeValueTypeObjC: CustomStringConvertible, CustomDebugStringConvertible {

    // MARK: - String convertible

    /// A human-readable string representation of the `SPLKAttributeValueType`.
    public var description: String {
        switch self {
        case .bool:
            return "BOOL"

        case .double:
            return "double"

        case .integer:
            return "NSInteger"

        case .string:
            return "NSString"
        }
    }

    /// A string representation of an `SPLKAttributeValueType` intended for diagnostic output.
    public var debugDescription: String {
        switch self {
        case .bool:
            return "SPLKAttributeValueTypeBool"

        case .double:
            return "SPLKAttributeValueTypeDouble"

        case .integer:
            return "SPLKAttributeValueTypeInteger"

        case .string:
            return "SPLKAttributeValueTypeString"
        }
    }
}
