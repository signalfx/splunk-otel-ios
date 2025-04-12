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
import SplunkSharedProtocols
import SplunkLogger


// MARK: - StringError: A Custom Error Type for Strings

struct StringError: Error {
    let message: String
}

// MARK: - CustomErrorTracking with ConstrainedAttributes

public struct CustomErrorTracking {

    public var typeName: String
    public unowned var sharedState: AgentSharedState?

    private let internalLogger = InternalLogger(configuration: .default(subsystem: "Splunk Agent", category: "ErrorTracking"))

    // Track method for SplunkTrackableIssue
    public func track(issue: SplunkTrackableIssue) {
        // Initialize ConstrainedAttributes
        var constrainedAttributes = ConstrainedAttributes<String>()

        // Obtain attributes from the issue
        let attributes = issue.toEventAttributes()

        // Validate and set key-value pairs using ConstrainedAttributes
        for (key, value) in attributes {
            if case .string(let stringValue) = value {
                if !constrainedAttributes.setAttribute(for: key, value: stringValue) {
                    internalLogger.log(level: .warning) {
                        "Invalid key or value length for key '\(key)'. Not publishing this issue."
                    }
                    return
                }
            }
        }

        TelemetryEmitter.emitSpan(data: issue, sharedState: sharedState, spanName: "ErrorTracking")
    }

    // Track method for Error
    public func track(issue: Error) {
        if let trackableIssue = issue as? SplunkTrackableIssue {
            track(issue: trackableIssue)
        } else {
            let customIssue = CustomError(issue: issue)
            track(issue: customIssue)
        }
    }

    // Track method for String
    public func track(issue: String) {
        let stringError = StringError(message: issue)
        track(issue: stringError)
    }
}
