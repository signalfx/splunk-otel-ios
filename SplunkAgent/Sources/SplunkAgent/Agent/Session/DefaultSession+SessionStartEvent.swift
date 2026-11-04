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

    /// A session start event that is held until its session produces telemetry.
    struct PendingSessionStart {
        let session: SessionItem
        let previousSessionId: String?
        let screenName: String?
    }

    /// Sends a "session start" event.
    ///
    /// A session's start event is sent when the session's first telemetry is accepted for export.
    /// If a session "transitions smoothly" into a new session, parameter `previousSessionId` should be included.
    ///
    /// - Parameters:
    ///   - sessionId: A session id of the started session.
    ///   - timestamp: The moment the session started.
    ///   - previousSessionId: A session id of the previous session, sent if the old session "transitions smoothly" into a new session.
    ///   - screenName: The screen shown when the session started.
    func sendSessionStart(sessionId: String, timestamp: Date, previousSessionId: String?, screenName: String?) {
        let event = SessionStartEvent(
            timestamp: timestamp,
            sessionId: sessionId,
            previousSessionId: previousSessionId,
            screenName: screenName
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

    /// The screen shown now, kept with a held session start, as the start may be sent later from another screen.
    ///
    /// Must not be called on `accessQueue`: reading the runtime attributes also reads the current session id.
    func screenNameForSessionStart() -> String? {
        owner?.runtimeAttributes.all[RuntimeAttributeKeys.screenName] as? String
    }
}
