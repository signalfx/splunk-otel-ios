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

    // Implement toEventAttributes as required by the protocol
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


extension Error {
    func asErrorData() -> ErrorData {
        return ErrorData(
            typeName: String(describing: type(of: self)),
            message: localizedDescription,
            stacktrace: Stacktrace(frames: Thread.callStackSymbols)
        )
    }
}

extension NSError {
    func asErrorData() -> ErrorData {
        return ErrorData(
            typeName: domain,
            message: localizedDescription,
            stacktrace: Stacktrace(frames: Thread.callStackSymbols)
        )
    }
}

extension NSException {
    func asErrorData() -> ErrorData {
        return ErrorData(
            typeName: name.rawValue,
            message: reason ?? "No reason provided",
            stacktrace: Stacktrace(frames: callStackSymbols)
        )
    }
}
