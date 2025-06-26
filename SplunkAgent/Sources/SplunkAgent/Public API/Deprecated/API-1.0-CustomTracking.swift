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

public extension SplunkRum {

    // MARK: - Custom Tracking

    /// Reports an error using a String. Legacy mapping.
    ///
    /// - Parameter string: A String error message.
    @available(
        *,
        deprecated,
        renamed: "SplunkRum.shared.customTracking.trackError(_:)",
        message: "This method will be removed in a later version."
    )
    static func reportError(string: String) {
        _ = shared.customTracking.trackError(string)
    }

    /// Reports an error with a Swift Error or NSError. Legacy mapping.
    ///
    /// - Parameter error: An instance of an Error-conforming type.
    @available(
        *,
        deprecated,
        renamed: "SplunkRum.shared.customTracking.trackError(_:)",
        message: "This method will be removed in a later version."
    )
    static func reportError(error: Error) {
        _ = shared.customTracking.trackError(error)
    }

    /// Reports an exception with an NSException. Legacy mapping.
    ///
    /// - Parameter exception: An NSException instance.
    @available(
        *,
        deprecated,
        renamed: "SplunkRum.shared.customTracking.trackException(_:)",
        message: "This method will be removed in a later version."
    )
    static func reportError(exception: NSException) {
        _ = shared.customTracking.trackException(exception)
    }

    /// Reports a custom event with name and attributes. Legacy mapping.
    ///
    /// - Parameter name: A user-assigned String name for the event.
    /// - Parameter attribues: An NSDictionary with user-provided event attributes.
    @available(
        *,
        deprecated,
        renamed: "SplunkRum.shared.customTracking.trackCustomEvent(_:_:)",
        message: "This method will be removed in a later version."
    )
    static func reportEvent(name: String, attributes: NSDictionary) {
        let mutableAttributes = MutableAttributes(from: attributes)
        _ = shared.customTracking.trackCustomEvent(name, mutableAttributes)
    }
}
