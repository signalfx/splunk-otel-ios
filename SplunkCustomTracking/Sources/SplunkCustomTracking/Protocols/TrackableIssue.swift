
import Foundation
import SplunkSharedProtocols


// MARK: - TrackableIssue Protocol

/// Protocol defining the requirements for errors that can be tracked.
/// Extends the base Trackable protocol with error-specific properties.
public protocol TrackableIssue: SplunkTrackable {

    /// A human-redable message describing the error
    var message: String { get }

    /// Optional stack trace information
    var stacktrace: Stacktrace? { get }
}


// MARK: - Default Implementation

public extension TrackableIssue {
    func toEventAttributes() -> [String: EventAttributeValue] {
        var attributes: [ErrorAttributeKeys.Exception: EventAttributeValue] = [
            .type: .string(typeName),
            .message: .string(message)
        ]

        if let stacktrace {
            attributes[.stacktrace] = .string(stacktrace.formatted)
        }

        return Dictionary(attributes)
    }
}

