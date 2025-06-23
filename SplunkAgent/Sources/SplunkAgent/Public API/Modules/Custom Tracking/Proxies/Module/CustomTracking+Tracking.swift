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
import OpenTelemetryApi

extension CustomTracking {


    // MARK: - Public API


    // MARK: - Custom Tracking - Events

    /// Track a custom event by name with attributes.
    @discardableResult func trackCustomEvent(_ name: String, _ attributes: MutableAttributes = MutableAttributes()) -> any CustomTrackingModule {
        module.track(SplunkTrackableEvent(eventName: name, attributes: attributes.toEventAttributes()))
        return self
    }


    // MARK: - Custom Tracking - Errors

    @discardableResult func trackError(_ message: String, _ attributes: MutableAttributes = MutableAttributes()) -> any CustomTrackingModule {
        module.track(SplunkIssue(from: message), attributes.toEventAttributes())
        return self
    }

    @discardableResult func trackError(_ error: Error, _ attributes: MutableAttributes = MutableAttributes()) -> any CustomTrackingModule {
        module.track(SplunkIssue(from: error), attributes.toEventAttributes())
        return self
    }

    @discardableResult func trackException(_ exception: NSException, _ attributes: MutableAttributes = MutableAttributes()) -> any CustomTrackingModule {
        module.track(SplunkIssue(from: exception), attributes.toEventAttributes())
        return self
    }

    // MARK: - Custom Tracking - Workflows

    func trackWorkflow(_ workflowName: String) -> Span {
        return module.track(workflowName)
    }
}
