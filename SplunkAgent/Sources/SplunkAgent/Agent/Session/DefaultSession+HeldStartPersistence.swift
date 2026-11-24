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

extension DefaultSession {

    // MARK: - Persisted held session starts

    /// The state of restoring the held starts that the previous run saved.
    ///
    /// The saved starts are read in the background. Until they are restored, the held starts are not
    /// saved, so that a save cannot overwrite the saved starts before they are merged, and releases of
    /// held starts wait, because the start a release is for may be one that is still being read.
    struct HeldStartRestoration {
        /// Whether the saved starts are being read and are not restored yet.
        var isRestoring = false

        /// The session ids whose held starts are released once the restoring finishes, in the order
        /// their releases came, each once.
        var deferredReleases: [String] = []
    }

    /// The age beyond which a saved session start is not restored.
    ///
    /// It matches how long the sessions list keeps a session, so a start is not sent once the agent
    /// has forgotten its session. Without a limit, a start that nothing released, for example after
    /// the app was killed before its first export, would be saved again at every launch.
    static let maxRestoredSessionStartAge: TimeInterval = SessionsModel.maxDataLifetime

    /// Saves the held session starts, so that the next launch can restore them.
    ///
    /// The save is requested in the order of the changes to the held starts, and written later
    /// by ``heldSessionStarts`` on its own queue. Storage calls can block, for example on file I/O or
    /// while data protection keeps the file closed, so they must never run on `accessQueue`.
    ///
    /// Does nothing while the starts saved by the previous run are restored: the merged list is saved
    /// when the restoring finishes, so a save cannot overwrite the saved starts before they are merged.
    ///
    /// Must run on `accessQueue`.
    func persistHeldSessionStarts() {
        guard !heldStartRestoration.isRestoring else {
            return
        }

        let records = pendingSessionStarts.map { pending in
            HeldSessionStartRecord(
                sessionId: pending.session.id,
                start: pending.session.start,
                previousSessionId: pending.previousSessionId,
                screenName: pending.screenName
            )
        }

        heldSessionStarts.save(records)
    }

    /// Restores saved session starts, so that late telemetry of their sessions can still release them.
    ///
    /// The restored starts go before the starts held now, oldest first, and the oldest are dropped
    /// beyond ``maxHeldSessionStarts``. A start already held now is not restored a second time, and
    /// a start older than ``maxRestoredSessionStartAge`` is not restored at all. The save of the
    /// merged list is requested here, not left to the next change of the held starts.
    ///
    /// Must run on `accessQueue`, after the restoring is marked finished, so that the merged list is saved.
    ///
    /// - Parameter records: The saved session starts, oldest first.
    func restoreHeldSessionStarts(_ records: [HeldSessionStartRecord]) {
        let heldSessionIds = Set(pendingSessionStarts.map(\.session.id))
        let oldestRestoredStart = Date().addingTimeInterval(-Self.maxRestoredSessionStartAge)
        let restored =
            records
            .filter { !heldSessionIds.contains($0.sessionId) && $0.start >= oldestRestoredStart }
            .map { record in
                PendingSessionStart(
                    session: SessionItem(id: record.sessionId, start: record.start),
                    previousSessionId: record.previousSessionId,
                    screenName: record.screenName
                )
            }

        pendingSessionStarts = restored + pendingSessionStarts
        dropHeldSessionStartsBeyondLimit()
        persistHeldSessionStarts()
    }

    /// Finishes restoring the held starts that the previous run saved, and runs the releases that waited for it.
    ///
    /// The restoring is marked finished first, so that the merged list is saved and the waiting
    /// releases send their starts. A failed read arrives as an empty list and finishes the same way.
    ///
    /// Must run on `accessQueue`.
    ///
    /// - Parameter records: The saved session starts, oldest first.
    func finishRestoringHeldSessionStarts(_ records: [HeldSessionStartRecord]) {
        let deferredReleases = heldStartRestoration.deferredReleases
        heldStartRestoration = HeldStartRestoration()

        restoreHeldSessionStarts(records)

        for sessionId in deferredReleases {
            releaseHeldSessionStart(forSessionId: sessionId)
        }
    }
}
