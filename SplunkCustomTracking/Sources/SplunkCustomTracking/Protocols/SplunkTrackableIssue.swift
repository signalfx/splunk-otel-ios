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
        message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        exceptionType = String(describing: type(of: error))
        timestamp = Date()

        // This is not necessarily the original error's throw site.
        stacktrace = Stacktrace(frames: Thread.callStackSymbols)

        if let nsError = error as? NSError {
            exceptionCode = .int(nsError.code)
            codeNamespace = nsError.domain
        }
        else {
            exceptionCode = nil
            codeNamespace = nil
        }
    }

    public init(from exception: NSException) {
        message = exception.reason ?? "No reason provided"
        exceptionType = String(describing: type(of: exception))
        timestamp = Date()
        stacktrace = Stacktrace(frames: exception.callStackSymbols)
        self.exceptionCode = nil
        self.codeNamespace = nil
    }
}
