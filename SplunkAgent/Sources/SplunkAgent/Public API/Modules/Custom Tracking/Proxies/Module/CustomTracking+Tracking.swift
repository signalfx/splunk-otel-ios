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

internal import SplunkCommon


extension CustomTracking {


    // MARK: - Public API

    /// Track a custom event.
    public func trackCustomEvent(_ name: String, _ attributes: MutableAttributes) {
        let event = SplunkTrackableEvent(typeName: name, attributes: attributes)
        module.track(event: event)
    }

    /// Track an error (String message) with optional attributes.
    public func trackError(_ message: String, _ attributes: MutableAttributes? = nil) {
        let issue = SplunkIssue(from: message)
        module.track(issue: issue, attributes: attributes ?? [:])
    }

    /// Track an Error (Swift conforming type) with optional attributes.
    public func trackError(_ error: Error, _ attributes: MutableAttributes? = nil) {
        let issue = SplunkIssue(from: error)
        module.track(issue: issue, attributes: attributes ?? [:])
    }

    /// Track an NSError object with optional attributes.
    public func trackError(_ nsError: NSError, _ attributes: MutableAttributes? = nil) {
        let issue = SplunkIssue(from: nsError)
        module.track(issue: issue, attributes: attributes ?? [:])
    }

    /// Track an NSException object with optional attributes.
    public func trackException(_ exception: NSException, _ attributes: MutableAttributes? = nil) {
        let issue = SplunkIssue(from: exception)
        module.track(issue: issue, attributes: attributes ?? [:])
    }
}
