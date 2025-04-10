
import Foundation
import SplunkSharedProtocols


// MARK: - SplunkTrackableIssue Protocol

/// Protocol defining the requirements for errors that can be tracked.
/// Extends the base Trackable protocol with error-specific properties.
public protocol SplunkTrackableIssue: SplunkTrackable {

    /// A human-redable message describing the error
    var message: String { get }

    /// Optional stack trace information
    var stacktrace: Stacktrace? { get }

    func asErrorData() -> ErrorData
}


// MARK: - Default Implementation

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


extension String: SplunkTrackableIssue {
    var typeName: String { "String" }
    var message: String { self }
    var stacktrace: Stacktrace? { nil }

    func asErrorData() -> ErrorData {
        return ErrorData(typeName: typeName, message: message, stacktrace: stacktrace)
    }
}

extension Error: SplunkTrackableIssue {
    var typeName: String { String(describing: type(of: self)) }
    var message: String { localizedDescription }
    var stacktrace: Stacktrace? { Stacktrace(frames: Thread.callStackSymbols) }

    func asErrorData() -> ErrorData {
        return ErrorData(typeName: typeName, message: message, stacktrace: stacktrace)
    }
}

extension NSError: SplunkTrackableIssue {
    var typeName: String { domain }
    var message: String { localizedDescription }
    var stacktrace: Stacktrace? { Stacktrace(frames: Thread.callStackSymbols) }

    func asErrorData() -> ErrorData {
        return ErrorData(typeName: typeName, message: message, stacktrace: stacktrace)
    }
}

extension NSException: SplunkTrackableIssue {
    var typeName: String { name.rawValue }
    var message: String { reason ?? "No reason provided" }
    var stacktrace: Stacktrace? { Stacktrace(frames: callStackSymbols) }

    func asErrorData() -> ErrorData {
        return ErrorData(typeName: typeName, message: message, stacktrace: stacktrace)
    }
}
