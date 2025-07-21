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
import SplunkCommon

/// Provides an initializer to convert from `SplunkCommon.EventAttributeValue` to an OpenTelemetry `AttributeValue`.
///
/// This extension simplifies the process of mapping attribute types between the Splunk agent's internal
/// event model and the OpenTelemetry standard.
public extension AttributeValue {
    /// Initializes an `AttributeValue` from a `SplunkCommon.EventAttributeValue`.
    ///
    /// This initializer maps the cases of `EventAttributeValue` (`.string`, `.int`, `.double`) directly
    /// to their corresponding `AttributeValue` types.
    ///
    /// - Note: The `.data` case is currently converted to a Base64-encoded string as a placeholder.
    /// - Parameter eventAttributeValue: The `EventAttributeValue` to convert.
    init(_ eventAttributeValue: EventAttributeValue) {
        switch eventAttributeValue {
        case let .string(eventAttributeValue):
            self = .string(eventAttributeValue)

        case let .int(eventAttributeValue):
            self = .int(eventAttributeValue)

        case let .double(eventAttributeValue):
            self = .double(eventAttributeValue)

        case let .data(eventAttributeValue):
            // ‼️ Placeholder solution
            self = .string(eventAttributeValue.base64EncodedString())
        }
    }
}
