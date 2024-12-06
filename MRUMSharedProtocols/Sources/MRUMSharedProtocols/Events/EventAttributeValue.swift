//
/*
Copyright 2024 Splunk Inc.

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

/// Attribute value for Event attributes. Supported types: `String`, `Int`, `Double`, `Data`.
public enum EventAttributeValue: Equatable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case data(Data)

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

public extension EventAttributeValue {
    init(_ value: String) {
        self = .string(value)
    }

    init(_ value: Int) {
        self = .int(value)
    }

    init(_ value: Double) {
        self = .double(value)
    }

    init(_ value: Data) {
        self = .data(value)
    }
}
