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


// MARK: - SplunkTrackableIssue Protocol


public protocol SplunkTrackableIssue: SplunkTrackable {
    var message: String { get }
    var stacktrace: Stacktrace? { get }
}


// MARK: - Default Implementation for SplunkTrackableIssue

extension SplunkTrackableIssue {
    public func toEventAttributes() -> [String: EventAttributeValue] {
        var attributes: [ErrorAttributeKeys.Exception: EventAttributeValue] = [
            .type: .string(typeName),
            .message: .string(message)
        ]

        if let stacktrace = stacktrace {
            attributes[.stacktrace] = .string(stacktrace.formatted)
        }

        return Dictionary(attributes)
    }
}


// MARK: - SplunkIssue: Wrapper for String or Error with SplunkTrackableIssue conformance

public struct SplunkIssue: SplunkTrackableIssue {
    public let message: String
    public let typeName: String
    public let timestamp: Date
    public var stacktrace: Stacktrace?

    // Initializer for String issues
    public init(from message: String) {
        self.message = message
        self.typeName = "CustomIssue"
        self.timestamp = Date()
        self.stacktrace = nil
    }

    // Initializer for Error
    public init(from error: Error) {
        self.message = (error as? LocalizedError)?.errorDescription ?? "Unknown error"
        self.typeName = String(describing: type(of: error))
        self.timestamp = Date()
        self.stacktrace = Stacktrace(frames: Thread.callStackSymbols)
    }

    // Initializer for NSError
    public init(from error: NSError) {
        self.message = error.localizedDescription
        self.typeName = error.domain
        self.timestamp = Date()
        self.stacktrace = Stacktrace(frames: Thread.callStackSymbols)
    }

    // Initializer for NSException
    public init(from exception: NSException) {
        self.message = exception.reason ?? "No reason provided"
        self.typeName = exception.name.rawValue
        self.timestamp = Date()
        self.stacktrace = Stacktrace(frames: exception.callStackSymbols)
    }
}


// MARK: - NSError Extension for SplunkTrackableIssue

extension NSError: SplunkTrackableIssue {
    public var typeName: String {
        return domain
    }

    public var message: String {
        return localizedDescription
    }

    public var stacktrace: Stacktrace? {
        return Stacktrace(frames: Thread.callStackSymbols)
    }
}

// MARK: - NSException Extension for SplunkTrackableIssue

extension NSException: SplunkTrackableIssue {
    public var typeName: String {
        return name.rawValue
    }

    public var message: String {
        return reason ?? "No reason provided"
    }

    public var stacktrace: Stacktrace? {
        return Stacktrace(frames: callStackSymbols)
    }
}

