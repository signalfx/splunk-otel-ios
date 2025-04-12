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


extension Dictionary where Key == String, Value == EventAttributeValue {

    mutating func setAttribute(for key: String, value: EventAttributeValue, maxKeyLength: Int = 1024, maxValueLength: Int = 2048) -> Bool {
        guard key.count <= maxKeyLength, value.description.count <= maxValueLength else {
            print("Invalid key or value length.")
            return false
        }
        self[key] = value
        return true
    }

    func apply<U>(mappingClosure: (String, EventAttributeValue) -> U) -> [String: U] {
        var mappedAttributes: [String: U] = [:]
        for (key, value) in self {
            let newValue = mappingClosure(key, value)
            mappedAttributes[key] = newValue
        }
        return mappedAttributes
    }

    mutating func apply(mutatingClosure: (String, inout EventAttributeValue) -> Void) {
        for (key, var value) in self {
            mutatingClosure(key, &value)
            self[key] = value
        }
    }
}
