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
import OpenTelemetryApi
import SplunkCommon


// MARK: - SplunkTrackableIssue Protocol

/// Protocol for marshalling CustomTracking issues of any type: `String`, `Error`, `NSError`, `NSExeption`
public protocol SplunkTrackableIssue: SplunkTrackable {

    /// The string message e. g. localizedDescription for the type
    var message: String { get }

    /// The type of the error, e.g. `NSError`, to be reported as OTel `exception.type`
    var exceptionType: String { get }

    /// An actual or derived stack trace from the error. Empty for String message errors.
    var stacktrace: Stacktrace? { get }
}


// MARK: - Default Implementation for SplunkTrackableIssue

public extension SplunkTrackableIssue {
    func toAttributesDictionary() -> [String: EventAttributeValue] {
        var attributes: [String: EventAttributeValue] = [:]

        // Set required attributes
        attributes[ErrorAttributeKeys.Exception.type.rawValue] = .string(exceptionType)
        attributes[ErrorAttributeKeys.Exception.message.rawValue] = .string(message)

        // Optionally set stacktrace if it exists
        if let stacktrace = stacktrace {
            attributes[ErrorAttributeKeys.Exception.stacktrace.rawValue] = .string(stacktrace.formatted)
        }

        // Add code and domain for NSErrors if they exist
        if let issue = self as? SplunkIssue {
            if let code = issue.exceptionCode {
                attributes["code"] = code
            }
            if let domain = issue.codeNamespace {
                attributes["domain"] = .string(domain)
            }
        }

        return attributes
    }
}


// MARK: - SplunkIssue Struct

public struct SplunkIssue: SplunkTrackableIssue {
    public let message: String
    public let exceptionType: String
    public let timestamp: Date
    public var stacktrace: Stacktrace?
    public let exceptionCode: EventAttributeValue?
    public let codeNamespace: String?

    // Initializers for SplunkIssue
    public init(from message: String) {
        self.message = message
        exceptionType = String(describing: type(of: message))
        timestamp = Date()
        stacktrace = nil
        exceptionCode = nil
        codeNamespace = nil
    }

    public init(from error: Error) {
        let nsError = error as NSError
        message = nsError.localizedDescription
        exceptionType = String(describing: type(of: error))
        timestamp = Date()

        // This is not necessarily the original error's throw site.
        stacktrace = Stacktrace(frames: Thread.callStackSymbols)

        exceptionCode = .int(nsError.code)
        codeNamespace = nsError.domain
    }

    public init(from exception: NSException) {
        message = exception.reason ?? "No reason provided"
        exceptionType = exception.name.rawValue
        timestamp = Date()
        stacktrace = Stacktrace(frames: exception.callStackSymbols)
        exceptionCode = nil
        codeNamespace = nil
    }
}
