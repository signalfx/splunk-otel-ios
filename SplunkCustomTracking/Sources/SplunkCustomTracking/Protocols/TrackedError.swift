
import Foundation


// MARK: - TrackedError Protocol

/// Protocol defining the requirements for errors that can be tracked.
/// Extends the base Trackable protocol with error-specific properties.
public protocol TrackedError: SplunkTrackable {

    /// A human-redable message describing the error
    var message: String { get }

    /// Optional stack trace information
    var stacktrace Stacktrace? { get }
}


// MARK: - Default Implementation

public extension TrackedError {
    func toEventAttributes() -> [String: EventAttributeValue] {
        var attributes: [ErrorAttributesKeys.Exception: EventAttributeValue] = [
	    .type: .string(typeName),
	    .message: .string(message)
	]

	if let stacktrace {
	    attributes[.stacktrace] = .string(stacktrace.formatted)
	}

	return Dictionary(attributes)
    }
}


// MARK: - Error Conformance

extension Error where Self: TrackedError {
    public var typeName: String { String(describing: type(of: self)) }
    public var message: String { localizedDescription }
    public var stacktrace: Stacktrace? {
        Stacktrace(frames: Thread.callStackSymbols)
    }
}


// MARK: - NSError Conformance

extension NSError where Self: TrackedError {
    public var typeName: String { domain }
    public var message: String { localizedDescription }
    public var stacktrace: Stacktrace? {
        Stacktrace(frames: Thread.callStackSymbols)
    }
}			


// MARK: - NSException Conformance

extension NSException where Self: TrackedError {
    public var typeName: String { name.rawValue }
    public var message: String { reason ?? "No reason provided" }
    public var stacktrace: Stacktrace? {
        Stacktrace(frames: Thread.callStackSymbols)
    }
}
