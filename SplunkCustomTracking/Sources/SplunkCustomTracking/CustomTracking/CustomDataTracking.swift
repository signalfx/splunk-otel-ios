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


// Constants for validation
let maxUserDataKeyValueLengthInChars = 2048


// Utility function to validate length of strings
// TODO: - Maybe replace with validated(forLimit:allowTruncation:)
func validateLength(of string: String, maxLength: Int) -> Bool {
    return string.count <= maxLength
}


// MARK: - CustomTracking implementation

class CustomDataTracking: CustomTracking {
    override init() {
        super.init()
    }

    func track(data: SplunkTrackableData) {

        let attributes = data.toEventAttributes()

        // TODO: - Determine the correct use of this property versus the serviceName in publishData()
        data.typeName = "custom"

        for (key, value) in attributes {
            guard validateLength(of: key, maxLength: maxUserDataKeyValueLengthInChars) else {
                print("Invalid key length: \(key)")
                return
            }

            // MARK: - switch used only for cases that require length validation

            switch value {
            case .string(let stringValue):
                guard validateLength(of: stringValue, maxLength: maxUserDataKeyValueLengthInChars) else {
                    print("Invalid value length for key: \(key)")
                    return
                }
            case .data(let dataValue):
                guard validateLength(of: dataValue, maxLength: maxUserDataKeyValueLengthInChars) else {
                    print("Invalid data length for key: \(key)")
                    return
                }
            default:
                break
            }

            publishData(data: data, serviceName: "customDataTracking")
        }
    }

    func isValidKey(_ key: String) -> Bool {
        return validateLength(of: key, maxLength: maxUserDataKeyValueLengthInChars)
    }
}
