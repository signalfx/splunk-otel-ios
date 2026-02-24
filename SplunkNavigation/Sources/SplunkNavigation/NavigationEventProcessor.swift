//
/*
Copyright 2026 Splunk Inc.

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

/// Transforms automated navigation events before they are handled by the module.
@objc(SPLKNavigationEventProcessor)
public protocol NavigationEventProcessor {

    // MARK: - Event processing

    /// Processes an automated navigation event.
    ///
    /// - Parameter event: The event produced by navigation detection.
    ///
    /// - Returns: The event to be used by the module.
    @objc(processEvent:)
    func process(event: NavigationEvent) -> NavigationEvent
}

/// A pass-through processor used by default.
@objc(SPLKDefaultNavigationEventProcessor)
public final class DefaultNavigationEventProcessor: NSObject, NavigationEventProcessor {

    // MARK: - Initialization

    @objc
    public override init() {
        super.init()
    }


    // MARK: - Event processing

    @objc(processEvent:)
    public func process(event: NavigationEvent) -> NavigationEvent {
        event
    }
}
