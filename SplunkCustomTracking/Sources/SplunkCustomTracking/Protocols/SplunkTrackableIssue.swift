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


// MARK: - Default Implementation for toEventAttributes

public extension SplunkTrackableIssue {
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


// MARK: - Add SplunkTrackableIssue conformance to Error types and SplunkIssue


// MARK: - SplunkIssue: Wrapper for String with SplunkTrackableIssue conformance

public struct SplunkIssue: SplunkTrackableIssue {
    public let message: String

    public var typeName: String {
        return "CustomIssue"
    }

    public var stacktrace: Stacktrace? {
        return nil
    }

    public init(_ message: String) {
        self.message = message
    }
}


// MARK: - Error Extension for SplunkTrackableIssue

extension Error: SplunkTrackableIssue {
    public var typeName: String {
        return String(describing: type(of: self))
    }

    public var message: String {
        return localizedDescription
    }

    public var stacktrace: Stacktrace? {
        return Stacktrace(frames: Thread.callStackSymbols)
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
