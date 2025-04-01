//
/*
Copyright 2024 Splunk Inc.

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
internal import SplunkSharedProtocols

/// Session Pulse Event. Sent in constant intervals to keep a session alive.
class SessionPulseEvent: AgentEvent {

    // MARK: - Initialization

    public init(sessionID: String, timestamp: Date) {
        super.init()

        // Event identification
        name = "session_pulse"
        instrumentationScope = "com.splunk.rum.agent"

        // Event properties
        self.sessionID = sessionID
        self.timestamp = timestamp
    }
}
