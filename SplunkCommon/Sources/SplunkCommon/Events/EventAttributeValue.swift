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

/// An attribute value for ``AgentEvent`` attributes. Supported types: `String`, `Int`, `Double`, `Data`.
public enum EventAttributeValue: Equatable, Hashable {
    /// A string attribute value.
    case string(String)
    /// An integer attribute value.
    case int(Int)
    /// A double-precision floating-point attribute value.
    case double(Double)
    /// A raw data attribute value.
    case data(Data)

    /// A string representation of the attribute's underlying value.
    public var description: String {
        switch self {
        case let .string(value):
            return value

        case let .int(value):
            return String(value)

        case let .double(value):
            return String(value)

        case let .data(value):
            return value.description
        }
    }
}

/// Adds convenience initializers for creating ``EventAttributeValue`` instances from raw types.
public extension EventAttributeValue {
    /// Initializes a `.string` case with the given `String` value.
    init(_ value: String) {
        self = .string(value)
    }

    /// Initializes an `.int` case with the given `Int` value.
    init(_ value: Int) {
        self = .int(value)
    }

    /// Initializes a `.double` case with the given `Double` value.
    init(_ value: Double) {
        self = .double(value)
    }

    /// Initializes a `.data` case with the given `Data` value.
    init(_ value: Data) {
        self = .data(value)
    }
}
