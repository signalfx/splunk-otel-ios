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

extension DefaultSession {

    // MARK: - Session start event

    /// Send initial session start evet explicitly.
    ///
    /// Initial session start event can't be sent by `DefaultSession` implicitly, because
    /// there is no `eventManager` initialized yet at the time of an initial session creation.
    internal func sendInitialSessionStartEvent() {
        sendSessionStart()
    }

    /// Sends a "session start" event.
    ///
    /// Session start event is sent with every session start. If a session "transitions smoothly" into a new session,
    /// parameter `previousSessionId` should be included.
    ///
    /// - Parameter previousSessionId: A session id of the previous session, sent if the old session "transitions smoothly" into a new session.
    internal func sendSessionStart(previousSessionId: String? = nil) {
        let currentId = currentSession.id
        let timestamp = currentSession.start

        let event = SessionStartEvent(
            timestamp: timestamp,
            sessionId: currentId,
            previousSessionId: previousSessionId
        )

        // Send session start event for a new session
        if let eventManager = owner?.eventManager {
            eventManager.sendEvent(event)
        }
        else {
            logger.log(level: .error) {
                "Could not send a session start event. Agent's event manager is not yet initialized."
            }
        }
    }
}
