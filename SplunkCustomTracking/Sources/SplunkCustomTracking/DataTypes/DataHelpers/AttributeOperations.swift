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
import SplunkSharedProtocols


protocol AttributeOperations {
    mutating func setAttribute(for key: String, value: EventAttributeValue, maxKeyLength: Int, maxValueLength: Int) -> Bool
    mutating func apply(mutating: (String, inout EventAttributeValue) -> Void)
}


extension Dictionary: AttributeOperations where Key == String, Value == EventAttributeValue {

    mutating func setAttribute(for key: String, value: EventAttributeValue, maxKeyLength: Int = 1024, maxValueLength: Int = 2048) -> Bool {
        guard key.count <= maxKeyLength, value.description.count <= maxValueLength else {
            return false
        }
        self[key] = value
        return true
    }

    mutating func apply(mutating: (String, inout EventAttributeValue) -> Void) {
        for (key, var value) in self {
            mutating(key, &value)
            self[key] = value
        }
    }
}
