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
    /// Converts the issue's details into a dictionary of OpenTelemetry attributes.
    ///
    /// This default implementation populates standard error attributes such as `exception.type`,
    /// `exception.message`, and `exception.stacktrace` from the conforming type's properties.
    /// - Returns: A dictionary of `[String: EventAttributeValue]` representing the issue.
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

/// A concrete implementation of `SplunkTrackableIssue` used to wrap common error types like `String`, `Error`, and `NSException`.
///
/// This struct standardizes different kinds of reportable issues into a single format that can be tracked by the agent.
public struct SplunkIssue: SplunkTrackableIssue {
    /// The primary descriptive message of the issue.
    public let message: String
    /// A string representing the type of the original error or exception (e.g., "MyCustomError").
    public let exceptionType: String
    /// The date and time when the issue was captured.
    public let timestamp: Date
    /// An optional stack trace associated with the issue.
    public var stacktrace: Stacktrace?
    /// An optional error code, typically extracted from an `NSError`.
    public let exceptionCode: EventAttributeValue?
    /// An optional namespace for the error code, such as an `NSError` domain.
    public let codeNamespace: String?

    // Initializers for SplunkIssue
    /// Initializes a `SplunkIssue` from a simple string message.
    ///
    /// No stack trace information is captured with this initializer.
    /// - Parameter message: The string describing the issue.
    public init(from message: String) {
        self.message = message
        exceptionType = String(describing: type(of: message))
        timestamp = Date()
        stacktrace = nil
        exceptionCode = nil
        codeNamespace = nil
    }

    /// Initializes a `SplunkIssue` from a Swift `Error`.
    ///
    /// This initializer extracts the error's description, type, and, if it's an `NSError`, its code and domain.
    /// - Warning: It captures the *current* call stack via `Thread.callStackSymbols`, which may not represent the original site where the error was thrown.
    /// - Parameter error: The `Error` object to track.
    public init(from error: Error) {
        message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        exceptionType = String(describing: type(of: error))
        timestamp = Date()

        // This is not necessarily the original error's throw site
        stacktrace = Stacktrace(frames: Thread.callStackSymbols)

        let nsError = error as NSError
        exceptionCode = .int(nsError.code)
        codeNamespace = nsError.domain
    }

    /// Initializes a `SplunkIssue` from an `NSException`.
    ///
    /// This initializer extracts the exception's reason, name, and call stack symbols.
    /// - Parameter exception: The `NSException` object to track.
    public init(from exception: NSException) {
        message = exception.reason ?? "No reason provided"
        exceptionType = String(describing: type(of: exception))
        timestamp = Date()
        stacktrace = Stacktrace(frames: exception.callStackSymbols)
        exceptionCode = nil
        codeNamespace = nil
    }
}
