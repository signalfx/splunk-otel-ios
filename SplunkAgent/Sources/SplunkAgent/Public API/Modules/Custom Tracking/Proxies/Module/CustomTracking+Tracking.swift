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
`
import Foundation
internal import SplunkCommon
internal import SplunkCustomTracking

extension CustomTracking {


    // MARK: - Public API

    /// Track a custom event.
    @discardableResult public func trackCustomEvent(_ name: String, _ attributes: MutableAttributes) -> any CustomTrackingModule {
        let event = SplunkTrackableEvent(typeName: name, attributes: attributes)
        module.track(event: event)
        return self
    }

    /// Track an error (String message) with optional attributes.
    @discardableResult public func trackError(_ message: String, _ attributes: MutableAttributes = MutableAttributes()) -> any CustomTrackingModule {
        let issue = SplunkIssue(from: message)

        // TODO: DEMRUM-861 something going on with the module here; it's resolving
        // this to the wrong track()ee
        module.track(issue: issue as SplunkTrackableIssue, attributes: attributes)
        return self
    }

    /// Track an Error (Swift conforming type) with optional attributes.
    @discardableResult public func trackError(_ error: Error, _ attributes: MutableAttributes = MutableAttributes()) -> any CustomTrackingModule {
        let issue = SplunkIssue(from: error)
        module.track(issue: issue, attributes: attributes)
        return self
    }

    /// Track an NSError object with optional attributes.
    @discardableResult public func trackError(_ nsError: NSError, _ attributes: MutableAttributes = MutableAttributes()) -> any CustomTrackingModule {
        let issue = SplunkIssue(from: nsError)
        module.track(issue: issue, attributes: attributes)
        return self
    }

    /// Track an NSException object with optional attributes.
    @discardableResult public func trackException(_ exception: NSException, _ attributes: MutableAttributes = MutableAttributes()) -> any CustomTrackingModule {
        let issue = SplunkIssue(from: exception)
        module.track(issue: issue, attributes: attributes)
        return self
    }
}
