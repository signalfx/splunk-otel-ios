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


// TODO: Determine whether we can collapse ErrorData and ErrorEventData into one.


// MARK: - ErrorData

struct ErrorData: SplunkTrackable {
    var typeName: String
    var message: String
    var stacktrace: Stacktrace?

    init(typeName: String, message: String, stacktrace: Stacktrace? = nil) {
        self.typeName = typeName
        self.message = message
        self.stacktrace = stacktrace
    }

    // protocol conformance requirement
    func toEventAttributes() -> [String: EventAttributeValue] {
        var attributes: [String: EventAttributeValue] = [
            "typeName": .string(typeName),
            "message": .string(message)
        ]

        if let stacktrace = stacktrace {
            attributes["stacktrace"] = .string(stacktrace.formatted)
        }

        return attributes
    }
}
