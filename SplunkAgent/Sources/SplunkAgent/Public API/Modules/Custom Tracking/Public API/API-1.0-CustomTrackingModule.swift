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

// TODO: DEMRUM-861: there are unnecessary MARKs, which are also causing lint issues. I'd suggest removing them.

// MARK: - CustomTracking

/// Defines a public API for the CustomTracking  module.
public protocol CustomTrackingModule {


    ///////
    // MARK: - Track Events
    ///////


    // MARK: - Track Custom Event

    /// Track a custom event with a name and attributes.
    ///
    /// - Parameter name: The event name assigned by the user.
    ///
    /// - Parameter attributes: MutableAttributes instance.
    ///
    /// - Returns: The updated `CustomTrackingModule` instance.
    @discardableResult func trackCustomEvent(_ name: String, _ attributes: MutableAttributes) -> any CustomTrackingModule


    ///////
    // MARK: - Track Errors
    ///////


    // MARK: - String Error
    
    /// Track an error (String message) with optional attributes.
    ///
    /// - Parameter message: A concise summary of the error condition.
    ///
    /// - Parameter attributes: Optional MutableAttributes instance to associate with the error.
    ///
    /// - Returns: The updated `CustomTrackingModule` instance.
    @discardableResult func trackError(_ message: String, _ attributes: MutableAttributes) -> any CustomTrackingModule


    // MARK: - Error
    
    /// Track an Error (Swift conforming type) with optional attributes.
    ///
    /// - Parameter error: An instance of a Swift type conforming to Error.
    ///
    /// - Parameter attributes: Optional MutableAttributes instance to associate with the error.
    ///
    /// - Returns: The updated `CustomTrackingModule` instance.
    @discardableResult func trackError(_ error: Error, _ attributes: MutableAttributes) -> any CustomTrackingModule


    // MARK: - NSError
    
    /// Track an NSError object with optional attributes.
    ///
    /// - Parameter nsError: An NSError object instance.
    ///
    /// - Parameter attributes: Optional MutableAttributes instance to associate with the error.
    ///
    /// - Returns: The updated `CustomTrackingModule` instance.
    @discardableResult func trackError(_ nsError: NSError, _ attributes: MutableAttributes) -> any CustomTrackingModule


    // MARK: - NSException

    /// Track an NSException object with optional attributes.
    ///
    /// - Parameter exception: An NSException instance such as one caught after a throw.
    ///
    /// - Parameter attributes: Optional MutableAttributes instance to associate with the error.
    ///
    /// - Returns: The updated `CustomTrackingModule` instance.
    @discardableResult func trackException(_ exception: NSException, _ attributes: MutableAttributes) -> any CustomTrackingModule


    // MARK: - Helpers

    @discardableResult func trackError(_ message: String) -> any CustomTrackingModule

    @discardableResult func trackError(_ error: Error) -> any CustomTrackingModule

    @discardableResult func trackError(_ nsError: NSError) -> any CustomTrackingModule

    @discardableResult func trackException(_ exception: NSException) -> any CustomTrackingModule
}


// MARK: - Helpers for Single Argument Invocation

extension CustomTrackingModule {

    // Get around the obstinance of protocols not letting calling code omit an argument

    @discardableResult func trackError(_ message: String) -> any CustomTrackingModule {
        return trackError(message, MutableAttributes())
    }

    @discardableResult func trackError(_ error: Error) -> any CustomTrackingModule {
        return trackError(error, MutableAttributes())
    }

    @discardableResult func trackError(_ nsError: NSError) -> any CustomTrackingModule {
        return trackError(nsError, MutableAttributes())
    }

    @discardableResult func trackException(_ exception: NSException) -> any CustomTrackingModule {
        return trackException(exception, MutableAttributes())
    }
}
