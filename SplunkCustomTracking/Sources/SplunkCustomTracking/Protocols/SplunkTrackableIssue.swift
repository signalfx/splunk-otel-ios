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
import SplunkCommon


// MARK: - SplunkTrackableIssue Protocol

public protocol SplunkTrackableIssue: SplunkTrackable {
    var message: String { get }
    var stacktrace: Stacktrace? { get }
}


// MARK: - Default Implementation for SplunkTrackableIssue

public extension SplunkTrackableIssue {
    var typeFamily: String {
        "Issue"
    }

    func toEventAttributes() -> [String: EventAttributeValue] {
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


// MARK: - SplunkIssue Struct

public struct SplunkIssue: SplunkTrackableIssue {
    public let message: String
    public let typeName: String
    public let timestamp: Date
    public var stacktrace: Stacktrace?

    // Initializers for SplunkIssue
    public init(from message: String) {
        self.message = message
        typeName = "CustomIssue"
        timestamp = Date()
        stacktrace = nil
    }

    public init(from error: Error) {
        message = (error as? LocalizedError)?.errorDescription ?? "Unknown error"
        typeName = String(describing: type(of: error))
        timestamp = Date()
        stacktrace = Stacktrace(frames: Thread.callStackSymbols)
    }

    public init(from nsError: NSError) {
        message = nsError.localizedDescription
        typeName = nsError.domain
        timestamp = Date()
        stacktrace = Stacktrace(frames: Thread.callStackSymbols)
    }

    public init(from exception: NSException) {
        message = exception.reason ?? "No reason provided"
        typeName = exception.name.rawValue
        timestamp = Date()
        stacktrace = Stacktrace(frames: exception.callStackSymbols)
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
