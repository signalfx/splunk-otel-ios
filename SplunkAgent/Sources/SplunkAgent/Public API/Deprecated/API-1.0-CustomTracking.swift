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

    /// Reports a string-based error.
    ///
    /// - Parameter string: The error message.
    @available(
        *,
        deprecated,
        renamed: "SplunkRum.shared.customTracking.trackError(_:)",
        message: "This method will be removed in a later version."
    )
    static func reportError(string: String) {
        _ = shared.customTracking.trackError(string)
    }

    /// Reports an error from a Swift `Error` or `NSError` instance.
    ///
    /// - Parameter error: An object that conforms to the `Error` protocol.
    @available(
        *,
        deprecated,
        renamed: "SplunkRum.shared.customTracking.trackError(_:)",
        message: "This method will be removed in a later version."
    )
    static func reportError(error: Error) {
        _ = shared.customTracking.trackError(error)
    }

    /// Reports an error from an `NSException` instance.
    ///
    /// - Parameter exception: An `NSException` instance.
    @available(
        *,
        deprecated,
        renamed: "SplunkRum.shared.customTracking.trackException(_:)",
        message: "This method will be removed in a later version."
    )
    static func reportError(exception: NSException) {
        _ = shared.customTracking.trackException(exception)
    }

    /// Reports a custom event with a name and attributes.
    ///
    /// - Parameter name: The name of the custom event.
    /// - Parameter attributes: A dictionary of attributes to associate with the event.
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