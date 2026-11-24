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

    /// The most start events held at once: the current session and the two sessions it replaced.
    ///
    /// Held starts are small and sessions rotate rarely (every 4 hours by default), so keeping the
    /// two latest replaced sessions covers buffered or long-running telemetry of those sessions.
    /// When the limit is exceeded, the oldest start is dropped.
    static let maxHeldSessionStarts = 3

    /// Holds the start event of the initial session until the session produces telemetry.
    ///
    /// A session without telemetry then contains no events at all, instead of a lone
    /// zero-duration session start event. Sessions created by ``rotateSession(previousSessionId:)``
    /// hold their start event themselves.
    ///
    /// Also starts restoring the starts still held when the previous run ended. They are read in the
    /// background, so this method does not wait for storage. Until the restoring finishes, the held
    /// starts are not saved and no held start is released: releases wait and run when it finishes,
    /// because the start a release is for may be one that is still being read. If a restoring is already running, a
    /// second one is not started, and the running one restores the saved starts.
    func scheduleSessionStart() {
        let screenName = screenNameForSessionStart()

        let isAlreadyRestoring = accessQueue.sync {
            let wasRestoring = heldStartRestoration.isRestoring

            // Marked first, so that holding the start below does not save over the saved starts
            heldStartRestoration.isRestoring = true
            holdSessionStart(PendingSessionStart(session: currentSession, previousSessionId: nil, screenName: screenName))

            return wasRestoring
        }

        guard !isAlreadyRestoring else {
            return
        }

        heldSessionStarts.load { [weak self] records in
            guard let self else {
                return
            }

            accessQueue.async { [weak self] in
                self?.finishRestoringHeldSessionStarts(records)
            }
        }
    }

    func trackAcceptedTelemetry(forSessionId sessionId: String) {
        accessQueue.async { [weak self] in
            self?.releaseHeldSessionStart(forSessionId: sessionId)
        }
    }

    /// Sends the held start event of a session, if there is one.
    ///
    /// While the saved held starts are restored, the release waits until the restoring finishes,
    /// because the start may be one that is still being read. Each session id waits once.
    ///
    /// Must run on `accessQueue`.
    func releaseHeldSessionStart(forSessionId sessionId: String) {
        if heldStartRestoration.isRestoring {
            if !heldStartRestoration.deferredReleases.contains(sessionId) {
                heldStartRestoration.deferredReleases.append(sessionId)
            }

            return
        }

        // The pending state is cleared first, as sending the event produces telemetry itself.
        guard let pending = takeHeldSessionStart(forSessionId: sessionId) else {
            return
        }

        sendSessionStart(
            sessionId: pending.session.id,
            timestamp: pending.session.start,
            previousSessionId: pending.previousSessionId,
            screenName: pending.screenName
        )
    }

    /// Holds a session's start event, dropping the oldest held starts beyond ``maxHeldSessionStarts``.
    ///
    /// The held starts are also saved, so that the next launch can restore them, unless the saved starts
    /// are being restored (see ``persistHeldSessionStarts()``).
    ///
    /// Must run on `accessQueue`.
    func holdSessionStart(_ pending: PendingSessionStart) {
        pendingSessionStarts.removeAll { $0.session.id == pending.session.id }
        pendingSessionStarts.append(pending)

        dropHeldSessionStartsBeyondLimit()
        persistHeldSessionStarts()
    }

    /// Removes and returns the held start event of a session, if there is one.
    ///
    /// The save of the held starts without this one is requested before the caller sends the event,
    /// so that a start that is sent is not restored and sent again at the next launch.
    ///
    /// Must run on `accessQueue`.
    func takeHeldSessionStart(forSessionId sessionId: String) -> PendingSessionStart? {
        guard let index = pendingSessionStarts.firstIndex(where: { $0.session.id == sessionId }) else {
            return nil
        }

        let pending = pendingSessionStarts.remove(at: index)
        persistHeldSessionStarts()

        return pending
    }

    /// Drops the oldest held starts beyond ``maxHeldSessionStarts``.
    ///
    /// Must run on `accessQueue`.
    func dropHeldSessionStartsBeyondLimit() {
        let excess = pendingSessionStarts.count - Self.maxHeldSessionStarts

        if excess > 0 {
            pendingSessionStarts.removeFirst(excess)
        }
    }

    /// Sends a "session start" event.
    ///
    /// A session's start event is sent when the session's first telemetry is accepted for export.
    /// If a session "transitions smoothly" into a new session, parameter `previousSessionId` should be included.
    ///
    /// Runs on `accessQueue`, so the event must be sent asynchronously: creating its span reads the current
    /// session id through `accessQueue`.
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

        // Send session start event for a new session. It goes to disk right away, because the
        // session's first data may have been saved when the app went to the background, and the
        // app can be killed before the next batch export.
        if let eventManager = owner?.eventManager {
            eventManager.sendEvent(event, persistImmediately: true)
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
