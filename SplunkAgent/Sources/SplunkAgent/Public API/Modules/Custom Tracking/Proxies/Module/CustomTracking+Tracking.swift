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
internal import SplunkCommon
internal import SplunkCustomTracking

extension CustomTracking {


    // MARK: - Public API


    /// Track a custom event by name with attributes.
    @discardableResult public func trackCustomEvent(_ name: String, _ attributes: MutableAttributes = MutableAttributes()) -> any CustomTrackingModule {
        let event = SplunkTrackableEvent(typeName: name, attributes: attributes)
        module.track(event: event) // internal track(event:)
        return self
    }

    @discardableResult public func trackError(_ error: Any, _ attributes: MutableAttributes = MutableAttributes()) -> any CustomTrackingModule {
        let issue: SplunkTrackableIssue

        if let stringError = error as? String {
            issue = SplunkIssue(from: stringError)
        } else if let swiftError = error as? Error {
            issue = SplunkIssue(from: swiftError)
        } else if let nsError = error as? NSError {
            issue = SplunkIssue(from: nsError)
        } else if let exception = error as? NSException {
            issue = SplunkIssue(from: exception)
        } else {
            print("Warning: Unsupported error type provided.")
            return self
        }

        module.track(issue, attributes)
        return self
    }
}
