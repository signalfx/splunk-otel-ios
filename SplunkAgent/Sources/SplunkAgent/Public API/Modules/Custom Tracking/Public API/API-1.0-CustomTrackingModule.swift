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

import Combine
import Foundation
import OpenTelemetryApi
internal import SplunkCommon

// MARK: - CustomTracking

/// Defines a public API for the CustomTracking  module.
public protocol CustomTrackingModule {

    // MARK: - Track Custom Events

    /// Track a custom event with a name and attributes.
    ///
    /// - Parameters:
    ///   - name: The event name assigned by the user.
    ///   - attributes: ``MutableAttributes`` instance.
    ///
    /// - Returns: The updated ``CustomTrackingModule`` instance.
    @discardableResult
    func trackCustomEvent(_ name: String, _ attributes: MutableAttributes) -> any CustomTrackingModule

    // MARK: - Track Errors

    /// Track an error (String message) with optional attributes.
    ///
    /// - Parameters:
    ///   - message: A concise summary of the error condition.
    ///   - attributes: Optional ``MutableAttributes`` instance to associate with the error.
    ///
    /// - Returns: The updated ``CustomTrackingModule`` instance.
    @discardableResult
    func trackError(_ message: String, _ attributes: MutableAttributes) -> any CustomTrackingModule

    /// Track an Error, including NSError (any Swift Error conforming type) with optional attributes.
    ///
    /// - Parameters:
    ///  - error: An instance of a type conforming to the Swift Error protocol.
    ///  - attributes: Optional ``MutableAttributes`` instance to associate with the error.
    ///
    /// - Returns: The updated ``CustomTrackingModule`` instance.
    @discardableResult
    func trackError(_ error: Error, _ attributes: MutableAttributes) -> any CustomTrackingModule


    /// Track an NSException object with optional attributes.
    ///
    /// - Parameters:
    ///  - exception: An NSException instance such as one caught after a throw.
    ///  - attributes: Optional ``MutableAttributes`` instance to associate with the error.
    ///
    /// - Returns: The updated ``CustomTrackingModule`` instance.
    @discardableResult
    func trackException(_ exception: NSException, _ attributes: MutableAttributes) -> any CustomTrackingModule


    // MARK: - Track Errors with an explicit stacktrace

    /// Track an error described by an explicit type, message, and stacktrace.
    ///
    /// Unlike the ``trackError(_:_:)-(Error,_)`` overloads, this method does not derive a
    /// native stacktrace: the supplied `stacktrace` is emitted verbatim as
    /// `exception.stacktrace`. It is intended for errors captured outside the native
    /// runtime - for example caught JavaScript/Dart errors bridged from the React Native
    /// or Flutter agents - whose stack must be preserved as-is for later symbolication.
    ///
    /// The resulting `component=error` span is named after `typeName` (falling back to
    /// `"error"` when empty) and carries `exception.type`, `exception.message`, and, when
    /// provided, `exception.stacktrace`. Provide cross-cutting context (such as
    /// `error.source` or `exception.escaped`) through `attributes`.
    ///
    /// - Parameters:
    ///   - typeName: The error type, reported as `exception.type` (for example `TypeError`).
    ///   - message: A concise summary of the error, reported as `exception.message`.
    ///   - stacktrace: The verbatim stacktrace, reported as `exception.stacktrace`.
    ///     Pass `nil` for string-only or stackless errors.
    ///   - attributes: Additional attributes to associate with the error span.
    ///
    /// - Returns: The updated ``CustomTrackingModule`` instance.
    @discardableResult
    func trackError(typeName: String, message: String, stacktrace: String?, attributes: [String: Any]) -> any CustomTrackingModule

    /// Track an error described by an explicit type, message, and stacktrace.
    ///
    /// A convenience overload of
    /// ``trackError(typeName:message:stacktrace:attributes:)`` that associates no
    /// additional attributes with the error span.
    ///
    /// - Parameters:
    ///   - typeName: The error type, reported as `exception.type` (for example `TypeError`).
    ///   - message: A concise summary of the error, reported as `exception.message`.
    ///   - stacktrace: The verbatim stacktrace, reported as `exception.stacktrace`.
    ///     Pass `nil` for string-only or stackless errors.
    ///
    /// - Returns: The updated ``CustomTrackingModule`` instance.
    @discardableResult
    func trackError(typeName: String, message: String, stacktrace: String?) -> any CustomTrackingModule


    // MARK: - Track Custom Workflow

    /// Track a workflow with a name and return a `Span` object.
    ///
    /// - Parameter workflowName: The name of the workflow to track.
    ///
    /// - Returns: A `Span` object representing the workflow.
    func trackWorkflow(_ workflowName: String) -> Span


    // MARK: - Single argument helpers (signatures)

    @discardableResult
    func trackCustomEvent(_ name: String) -> any CustomTrackingModule

    @discardableResult
    func trackError(_ message: String) -> any CustomTrackingModule

    @discardableResult
    func trackError(_ error: Error) -> any CustomTrackingModule

    @discardableResult
    func trackException(_ exception: NSException) -> any CustomTrackingModule
}

extension CustomTrackingModule {

    // MARK: - Custom Event single argument helper

    @discardableResult
    func trackCustomEvent(_ name: String) -> any CustomTrackingModule {
        trackCustomEvent(name, MutableAttributes())
    }
}

extension CustomTrackingModule {

    // MARK: - Error single argument helpers

    @discardableResult
    func trackError(_ message: String) -> any CustomTrackingModule {
        trackError(message, MutableAttributes())
    }

    @discardableResult
    func trackError(_ error: Error) -> any CustomTrackingModule {
        trackError(error, MutableAttributes())
    }

    @discardableResult
    func trackException(_ exception: NSException) -> any CustomTrackingModule {
        trackException(exception, MutableAttributes())
    }
}

extension CustomTrackingModule {

    // MARK: - Explicit stacktrace error helpers

    /// Default fallback for consumers that do not implement the explicit-stack API.
    @discardableResult
    func trackError(typeName: String, message: String, stacktrace: String?, attributes: [String: Any]) -> any CustomTrackingModule {
        var forwarded = attributes
        forwarded["exception.type"] = typeName
        if let stacktrace {
            forwarded["exception.stacktrace"] = stacktrace
        }

        return trackError(message, MutableAttributes(from: forwarded))
    }

    @discardableResult
    func trackError(typeName: String, message: String, stacktrace: String?) -> any CustomTrackingModule {
        trackError(typeName: typeName, message: message, stacktrace: stacktrace, attributes: [:])
    }
}
