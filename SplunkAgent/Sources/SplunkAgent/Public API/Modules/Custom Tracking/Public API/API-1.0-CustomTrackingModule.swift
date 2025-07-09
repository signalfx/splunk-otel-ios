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

/// Defines a public API for the CustomTracking  module.
public protocol CustomTrackingModule {

    // MARK: - Track Custom Events

    /// Track a custom event with a name and attributes.
    ///
    /// - Parameter name: The event name assigned by the user.
    ///
    /// - Parameter attributes: MutableAttributes instance.
    ///
    /// - Returns: The updated `CustomTrackingModule` instance.
    @discardableResult func trackCustomEvent(_ name: String, _ attributes: MutableAttributes) -> any CustomTrackingModule

    // MARK: - Track Errors

    /// Track an error (String message) with optional attributes.
    ///
    /// - Parameter message: A concise summary of the error condition.
    ///
    /// - Parameter attributes: Optional MutableAttributes instance to associate with the error.
    ///
    /// - Returns: The updated `CustomTrackingModule` instance.
    @discardableResult func trackError(_ message: String, _ attributes: MutableAttributes) -> any CustomTrackingModule

    /// Track an Error, including NSError (any Swift Error conforming type) with optional attributes.
    ///
    /// - Parameter error: An instance of a type conforming to the Swift Error protocol.
    ///
    /// - Parameter attributes: Optional MutableAttributes instance to associate with the error.
    ///
    /// - Returns: The updated `CustomTrackingModule` instance.
    @discardableResult func trackError(_ error: Error, _ attributes: MutableAttributes) -> any CustomTrackingModule


    /// Track an NSException object with optional attributes.
    ///
    /// - Parameter exception: An NSException instance such as one caught after a throw.
    ///
    /// - Parameter attributes: Optional MutableAttributes instance to associate with the error.
    ///
    /// - Returns: The updated `CustomTrackingModule` instance.
    @discardableResult func trackException(_ exception: NSException, _ attributes: MutableAttributes) -> any CustomTrackingModule


    // MARK: - Track Custom Workflow

    /// Track a workflow with a name and return a Span object.
    ///
    /// - Parameter workflowName: The name of the workflow to track.
    ///
    /// - Returns: A Span object representing the workflow.
    func trackWorkflow(_ workflowName: String) -> Span


    // MARK: - Single argument helpers (signatures)

    @discardableResult func trackCustomEvent(_ name: String) -> any CustomTrackingModule

    @discardableResult func trackError(_ message: String) -> any CustomTrackingModule

    @discardableResult func trackError(_ error: Error) -> any CustomTrackingModule

    @discardableResult func trackException(_ exception: NSException) -> any CustomTrackingModule
}

extension CustomTrackingModule {

    // MARK: - Custom Event single argument helper

    @discardableResult func trackCustomEvent(_ name: String) -> any CustomTrackingModule {
        return trackCustomEvent(name, MutableAttributes())
    }
}

extension CustomTrackingModule {

    // MARK: - Error single argument helpers

    @discardableResult func trackError(_ message: String) -> any CustomTrackingModule {
        return trackError(message, MutableAttributes())
    }

    @discardableResult func trackError(_ error: Error) -> any CustomTrackingModule {
        return trackError(error, MutableAttributes())
    }

    @discardableResult func trackException(_ exception: NSException) -> any CustomTrackingModule {
        return trackException(exception, MutableAttributes())
    }
}
