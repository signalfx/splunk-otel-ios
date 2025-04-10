
import Foundation
import SplunkSharedProtocols


// MARK: - SplunkTrackableIssue Protocol

public protocol SplunkTrackableIssue: SplunkTrackable {

    var message: String { get }

    var stacktrace: Stacktrace? { get }
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
}

