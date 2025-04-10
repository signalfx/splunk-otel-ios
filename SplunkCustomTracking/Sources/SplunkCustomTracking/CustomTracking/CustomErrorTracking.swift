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
import SplunkSharedProtocols
import SplunkLogger


// MARK: - String length validation helper

// TODO: - Move this to a home for utility functions and let CustomDataTracking use it as well

extension String {
    func validated(forLimit maxLength: Int, allowTruncated: Bool) -> String? {
        if self.count <= maxLength {
            return self
        } else if allowTruncated {
            let truncatedValue = String(self.prefix(maxLength - 3)) + "..."
            internalLogger.log(level: .warning) {
                "Value for key '\(self.prefix(10))...' exceeds max length. Truncating value."
            }
            return truncatedValue
        }
        return nil
    }
}


public struct CustomErrorTracking: CustomTracking {
    public var typeName: String
    public unowned var sharedState: AgentSharedState?

    private let internalLogger = InternalLogger(configuration: .default(subsystem: "Splunk Agent", category: "ErrorTracking"))

    public func track(issue: SplunkTrackableIssue) {
        // Obtain attributes from the issue
        let attributes = issue.toEventAttributes()
        let maxLength = maxUserDataKeyValueLengthInChars

        // TODO: - Determine the correct use of this property versus the serviceName in publishData()
        issue.typeName = "error"

        for (key, value) in attributes {

            // Validate key length
            guard let validKey = key.validated(forLimit: maxLength, allowTruncated: false) else {
                internalLogger.log(level: .error) {
                    "Key '\(key)' exceeds max length. Not publishing this issue."
                }
                return
            }

            // Validate value length
            if case .string(let stringValue) = value {
                if let validValue = stringValue.validated(forLimit: maxLength, allowTruncated: true) {
                    attributes[validKey] = .string(validValue)
                } else {
                    internalLogger.log(level: .warning) {
                        "Value for key '\(validKey)' exceeds max length. Not publishing this issue."
                    }
                    return
                }
            }

            publishData(data: issue, serviceName: "errorTracking")
        }
    }
}

