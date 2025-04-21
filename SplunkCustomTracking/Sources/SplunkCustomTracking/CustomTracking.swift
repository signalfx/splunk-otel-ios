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
import SplunkSharedProtocols


public final class CustomTracking {

    public static var instance = CustomTracking()


    // MARK: - Private Properties

    private var eventTracking = EventTracking()
    private var errorTracking = ErrorTracking()

    // Shared state
    public unowned var sharedState: AgentSharedState?


    // Module conformance
    public required init() {}


    // MARK: - Initialization

    public init(sharedState: AgentSharedState? = nil) {
        self.sharedState = sharedState
    }


    // MARK: - Public API

    /// Track a custom event.
    public func trackEvent(_ name: String, attributes: [String: Any]) {
        let event = SplunkTrackableEvent(typeName: name, attributes: attributes)
        eventTracking.track(event)
    }

    /// Track any kind of issue (String message, Error, NSError, NSException).

    public func track(issue: String) {
        let internalIssue = SplunkIssue(from: issue)
        errorTracking.track(internalIssue)
    }

    public func track(issue: Error) {
        let internalIssue = SplunkIssue(from: issue)
        errorTracking.track(internalIssue)
    }

    public func track(issue: NSError) {
        let internalIssue = SplunkIssue(from: issue)
        errorTracking.track(internalIssue)
    }

    public func track(issue: NSException) {
        let internalIssue = SplunkIssue(from: issue)
        errorTracking.track(internalIssue)
    }
}
