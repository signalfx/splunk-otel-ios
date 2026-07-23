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

/// Protocol for marshalling CustomTracking issues of any type: `String`, `Error`, `NSError`, `NSExeption`.
public protocol SplunkTrackableIssue: SplunkTrackable {

    /// The string message e. g. localizedDescription for the type.
    var message: String { get }

    /// The type of the error, e.g. `NSError`, to be reported as OTel `exception.type`.
    var exceptionType: String { get }

    /// An actual or derived stack trace from the error. Empty for String message errors.
    var stacktrace: Stacktrace? { get }
}


// MARK: - Default Implementation for SplunkTrackableIssue

extension SplunkTrackableIssue {
    public func toAttributesDictionary() -> [String: EventAttributeValue] {
        toAttributesDictionary(includingExceptionThreads: true)
    }

    func toAttributesDictionary(includingExceptionThreads: Bool) -> [String: EventAttributeValue] {
        var attributes: [String: EventAttributeValue] = [:]

        // Set required attributes
        attributes[ErrorAttributeKeys.Exception.type.rawValue] = .string(exceptionType)
        attributes[ErrorAttributeKeys.Exception.message.rawValue] = .string(message)

        // Optionally set stacktrace if it exists
        if let stacktrace {
            attributes[ErrorAttributeKeys.Exception.stacktrace.rawValue] = .string(stacktrace.formatted)

            if includingExceptionThreads, let threadList = stacktrace.threadList {
                attributes[ErrorAttributeKeys.Exception.threads.rawValue] = .string(threadList)
            }
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

    // MARK: - Public

    public let message: String
    public let exceptionType: String
    public let timestamp: Date
    public var stacktrace: Stacktrace?
    public let exceptionCode: EventAttributeValue?
    public let codeNamespace: String?

    // MARK: - Initialization

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

        // Manually-created NSException instances may not carry a stack.
        let frames = exception.callStackSymbols
        stacktrace = Stacktrace(frames: frames.isEmpty ? Thread.callStackSymbols : frames)
        exceptionCode = nil
        codeNamespace = nil
    }
}


// MARK: - SplunkExplicitIssue Struct

/// A trackable issue whose type, message, and stacktrace are supplied explicitly
/// by the caller, rather than derived from the native runtime.
///
/// This backs the explicit-stacktrace `trackError` API used by the hybrid agents
/// (React Native, Flutter). Unlike `SplunkIssue`, it never reads
/// `Thread.callStackSymbols`: the provided `stacktrace` is emitted verbatim as
/// `exception.stacktrace` so it stays usable as the raw symbolication input. The
/// `message` is truncated to a bounded length so an oversized payload still
/// produces a valid span (the stacktrace is preferred and kept).
public struct SplunkExplicitIssue: SplunkTrackableIssue {

    // MARK: - Constants

    /// Maximum number of characters retained for `exception.message`.
    ///
    /// Oversized messages are truncated first (the stacktrace is preferred) so the
    /// emitted span stays within OTLP/collector attribute limits.
    static let messageCharacterLimit = 4096


    // MARK: - Public

    public let message: String
    public let exceptionType: String
    public let timestamp: Date
    public var stacktrace: Stacktrace?


    // MARK: - Initialization

    /// Creates an explicitly-supplied issue.
    ///
    /// - Parameters:
    ///   - typeName: The error type reported as `exception.type` (for example `TypeError`).
    ///   - message: The error message reported as `exception.message`. Truncated to
    ///     ``messageCharacterLimit`` characters when longer.
    ///   - stacktrace: The verbatim stacktrace reported as `exception.stacktrace`.
    ///     Pass `nil` for string-only or stackless errors.
    public init(typeName: String, message: String, stacktrace: String?) {
        exceptionType = typeName
        self.message = Self.truncate(message, limit: Self.messageCharacterLimit)
        timestamp = Date()
        self.stacktrace = stacktrace.map { Stacktrace(raw: $0) }
    }


    // MARK: - Helpers

    /// Truncates `value` to at most `limit` characters, appending an ellipsis when shortened.
    ///
    /// Walks at most `limit` characters, avoiding a full traversal of a potentially huge string.
    private static func truncate(_ value: String, limit: Int) -> String {
        let prefix = value.prefix(limit)
        if prefix.endIndex == value.endIndex {
            return value
        }

        return String(prefix) + "…"
    }
}
