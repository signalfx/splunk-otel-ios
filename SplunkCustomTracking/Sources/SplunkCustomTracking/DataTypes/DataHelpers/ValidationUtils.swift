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
import SplunkLogger

// Constants for maximum allowed lengths
let maxKeyLength = 1024
let maxValueLength = 2048

/// Validates the lengths of keys and values in a dictionary of attributes.
/// Logs a warning message if any attribute exceeds the maximum length.
/// - Parameters:
///   - attributes: The dictionary of attributes to validate.
///   - logger: The logger to use for warning messages.
/// - Returns: A boolean indicating whether all attributes are valid.
func validateAttributeLengths(attributes: [String: EventAttributeValue], logger: InternalLogger) -> Bool {
    for (key, value) in attributes {
        if key.count > maxKeyLength {
            logger.log(level: .warning) {
                "Invalid key length for key '\(key)'. Not publishing this event."
            }
            return false
        }
        if let stringValue = value as? String, stringValue.count > maxValueLength {
            logger.log(level: .warning) {
                "Invalid value length for key '\(key)'. Not publishing this event."
            }
            return false
        }
    }
    return true
}
