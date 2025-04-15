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

// MARK: - validateAttributeLengths

// Validate the lengths of keys and values in a dictionary of attributes.
func validateAttributeLengths(attributes: [String: EventAttributeValue], logger: InternalLogger) -> Bool {

    func logAndReturnFalse(type: String, key: String) -> Bool {
        logger.log(level: .warning) {
            "Invalid \(type) length for key '\(key)'. Not publishing this event."
        }
        return false
    }

    for (key, value) in attributes {
        if key.count > maxKeyLength {
            return logAndReturnFalse(type: "key", key: key)
        }
        if let stringValue = value as? String, stringValue.count > maxValueLength {
            return logAndReturnFalse(type: "value", key: key)
        }
    }
    return true
}
