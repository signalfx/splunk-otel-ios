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
import SplunkCommon

@testable import SplunkAgent

/// An event manager that records the events the agent sends instead of sending them.
///
/// It still builds the real trace pipeline, so spans exported through it reach the agent.
final class MockEventManager: DefaultEventManager {

    // MARK: - Private

    private let lock = NSLock()
    private var events: [AgentEvent] = []
    private var handler: ((AgentEvent) -> Void)?


    // MARK: - Recorded events

    /// The events sent so far, in the order they were sent.
    var sentEvents: [AgentEvent] {
        lock.withLock { events }
    }

    /// A closure called with each sent event, on the thread that sent it.
    var sentEventHandler: ((AgentEvent) -> Void)? {
        get { lock.withLock { handler } }
        set { lock.withLock { handler = newValue } }
    }


    // MARK: - Internal events

    override func sendEvent(_ event: AgentEvent) {
        let handler = lock.withLock {
            events.append(event)

            return self.handler
        }

        handler?(event)
    }
}
