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
import SplunkLogger
import OpenTelemetryApi



public final class SplunkCustomTracking {


    // MARK: - Private Properties

    private let eventTracking: EventTracking
    private let errorTracking: ErrorTracking

    // Shared state
    public unowned var sharedState: AgentSharedState?


    // Module conformance
    public required init() {}


    // MARK: - Initialization

    public init(sharedState: AgentSharedState? = nil) {
        self.sharedState = sharedState
        self.eventTracking = EventTracking(typeName: "CustomEventType", sharedState: sharedState)
        self.errorTracking = ErrorTracking(typeName: "CustomErrorType", sharedState: sharedState)
    }


    // MARK: - Public API

    /// Tracks a custom event.
    public func trackEvent(event: SplunkTrackableEvent) {
        eventTracking.sharedState = sharedState
        eventTracking.track(event: event)
    }

    /// Tracks a custom issue (Error, NSError, NSException, wrapped String).
    public func track(issue: SplunkTrackableIssue) {
        errorTracking.sharedState = sharedState
        errorTracking.track(issue: issue)
    }

    /// Overloaded method for String issue.
    public func track(issue: String) {
        let wrappedIssue = SplunkIssue(issue)
        track(issue: wrappedIssue)
    }
}
