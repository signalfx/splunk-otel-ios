//
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

import OpenTelemetryApi

public extension SplunkAttributeValue {

    /// Converts `AttributeValue` to `SplunkAttributeValue`.
    init(otelAttributeValue attributeValue: AttributeValue) {
        switch attributeValue {
        case let .string(attributeValue):
            self = .string(attributeValue)

        case let .bool(attributeValue):
            self = .bool(attributeValue)

        case let .int(attributeValue):
            self = .int(attributeValue)

        case let .double(attributeValue):
            self = .double(attributeValue)

        case let .stringArray(attributeValue):
            self = .stringArray(attributeValue)

        case let .boolArray(attributeValue):
            self = .boolArray(attributeValue)

        case let .intArray(attributeValue):
            self = .intArray(attributeValue)

        case let .doubleArray(attributeValue):
            self = .doubleArray(attributeValue)

        case let .array(attributeValue):
            self = .array(attributeValue)

        case let .set(attributeValue):
            self = .set(attributeValue)
        }
    }
}
