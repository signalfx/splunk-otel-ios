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


// MARK: - CustomTracking

/// Defines a public API for the CustomTracking  module.
public protocol CustomTrackingModule {


    // MARK: - Track Events

    /// Track a custom event.
    func trackCustomEvent(_ name: String, _ attributes: [String: Any])


    // MARK: - Track Errors

    /// Track an error (String message) with optional attributes.
    func trackError(_ message: String, _ attributes: [String: Any]?)

    /// Track an Error (Swift conforming type) with optional attributes.
    func trackError(_ error: Error, _ attributes: [String: Any]?)

    /// Track an NSError object with optional attributes.
    func trackError(_ nsError: NSError, _ attributes: [String: Any]?)

    /// Track an NSException object with optional attributes.
    func trackException(_ exception: NSException, _ attributes: [String: Any]?)


    // helpers
    func trackError(_ message: String)
    func trackError(_ error: Error)
    func trackError(_ nsError: NSError)
    func trackException(_ exception: NSException)
}


extension CustomTrackingModule {
    // Get around the obstinance of protocols not letting calling code omit an argument
    func trackError(_ message: String) {
        trackError(message, nil)
    }

    func trackError(_ error: Error) {
        trackError(error, nil)
    }

    func trackError(_ nsError: NSError) {
        trackError(nsError, nil)
    }

    func trackException(_ exception: NSException) {
        trackException(exception, nil)
    }
}
