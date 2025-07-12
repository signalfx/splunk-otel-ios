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
internal import SplunkCommon
import OpenTelemetryApi


// MARK: - CustomTracking

/// An interface for tracking custom application events, errors, and user-defined workflows.
public protocol CustomTrackingModule {

    // MARK: - Track Custom Events

    /// Tracks a custom event with a specific name and optional attributes.
    ///
    /// - Parameter name: The name of the event.
    /// - Parameter attributes: A ``MutableAttributes`` object containing attributes for the event.
    /// - Returns: The `CustomTrackingModule` instance to allow for chaining.
    @discardableResult func trackCustomEvent(_ name: String, _ attributes: MutableAttributes) -> any CustomTrackingModule

    // MARK: - Track Errors

    /// Tracks a string-based error with optional attributes.
    ///
    /// - Parameter message: A concise summary of the error condition.
    /// - Parameter attributes: A ``MutableAttributes`` object to associate with the error.
    /// - Returns: The `CustomTrackingModule` instance to allow for chaining.
    @discardableResult func trackError(_ message: String, _ attributes: MutableAttributes) -> any CustomTrackingModule

    /// Tracks an error based on a Swift `Error` object, with optional attributes.
    ///
    /// - Parameter error: An instance of a type conforming to the `Error` protocol.
    /// - Parameter attributes: A ``MutableAttributes`` object to associate with the error.
    /// - Returns: The `CustomTrackingModule` instance to allow for chaining.
    @discardableResult func trackError(_ error: Error, _ attributes: MutableAttributes) -> any CustomTrackingModule


    /// Tracks an error based on an `NSException` object, with optional attributes.
    ///
    /// - Parameter exception: An `NSException` instance.
    /// - Parameter attributes: A ``MutableAttributes`` object to associate with the error.
    /// - Returns: The `CustomTrackingModule` instance to allow for chaining.
    @discardableResult func trackException(_ exception: NSException, _ attributes: MutableAttributes) -> any CustomTrackingModule


    // MARK: - Track Custom Workflow

    /// Starts a new span to track a multi-step user workflow.
    ///
    /// - Warning: You are responsible for ending the returned `Span` by calling its `end()` method
    ///            at the appropriate time. Failure to do so will result in a leaked span.
    ///
    /// - Parameter workflowName: The name of the workflow to track.
    /// - Returns: A `Span` object representing the workflow.
    ///
    /// ### Example ###
    /// ```
    /// let workflow = SplunkRum.shared.customTracking.trackWorkflow("Onboarding")
    /// // ... perform onboarding steps ...
    /// workflow.end()
    /// ```
    func trackWorkflow(_ workflowName: String) -> Span


    // MARK: - Single argument helpers (signatures)

    /// Tracks a custom event with a specific name and no additional attributes.
    ///
    /// - Parameter name: The name of the event.
    /// - Returns: The `CustomTrackingModule` instance to allow for chaining.
    @discardableResult func trackCustomEvent(_ name: String) -> any CustomTrackingModule

    /// Tracks a string-based error with no additional attributes.
    ///
    /// - Parameter message: A concise summary of the error condition.
    /// - Returns: The `CustomTrackingModule` instance to allow for chaining.
    @discardableResult func trackError(_ message: String) -> any CustomTrackingModule

    /// Tracks an error based on a Swift `Error` object with no additional attributes.
    ///
    /// - Parameter error: An instance of a type conforming to the `Error` protocol.
    /// - Returns: The `CustomTrackingModule` instance to allow for chaining.
    @discardableResult func trackError(_ error: Error) -> any CustomTrackingModule

    /// Tracks an error based on an `NSException` object with no additional attributes.
    ///
    /// - Parameter exception: An `NSException` instance.
    /// - Returns: The `CustomTrackingModule` instance to allow for chaining.
    @discardableResult func trackException(_ exception: NSException) -> any CustomTrackingModule
}

extension CustomTrackingModule {

    // MARK: - Custom Event single argument helper

    /// Tracks a custom event with a specific name and no additional attributes.
    @discardableResult public func trackCustomEvent(_ name: String) -> any CustomTrackingModule {
        return trackCustomEvent(name, MutableAttributes())
    }
}

extension CustomTrackingModule {

    // MARK: - Error single argument helpers

    /// Tracks a string-based error with no additional attributes.
    @discardableResult public func trackError(_ message: String) -> any CustomTrackingModule {
        return trackError(message, MutableAttributes())
    }

    /// Tracks an error based on a Swift `Error` object with no additional attributes.
    @discardableResult public func trackError(_ error: Error) -> any CustomTrackingModule {
        return trackError(error, MutableAttributes())
    }

    /// Tracks an error based on an `NSException` object with no additional attributes.
    @discardableResult public func trackException(_ exception: NSException) -> any CustomTrackingModule {
        return trackException(exception, MutableAttributes())
    }
}