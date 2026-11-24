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

import SplunkCommon
import XCTest

@testable import SplunkAgent

/// Tests that the held starts saved by the previous run are restored in the background.
///
/// Each test simulates a relaunch: a second session object on the same storage, as at the next launch.
final class HeldSessionStartRestorationTests: XCTestCase {

    // MARK: - Private

    /// Keeps agents alive, as a session only holds an unowned reference to its agent.
    private var retainedAgents: [SplunkRum] = []

    /// Waiting time for something that must happen.
    ///
    /// The wait ends as soon as it happens, so a generous limit costs nothing when the code works,
    /// and a slow or stalled test machine does not fail the test.
    private let arrivalTimeout: TimeInterval = 10


    // MARK: - Setup

    override func setUp() {
        super.setUp()

        retainedAgents = []
        restoreOpenTelemetryGlobalsAtTeardown()
    }

    override func tearDown() {
        retainedAgents = []

        super.tearDown()
    }


    // MARK: - Blocked read

    func testReleaseOfSavedStartWaitsForBlockedRead() throws {
        // The previous run ends while holding the start of a session that replaced another one
        let (firstRun, _) = try buildSession(named: "heldStartBlockedReadTest")
        firstRun.scheduleSessionStart()
        let replacedSessionId = firstRun.currentSessionId

        firstRun.owner?.runtimeAttributes.updateScreenName("RotatedScreen")
        firstRun.rotateSession(previousSessionId: replacedSessionId)
        let savedSessionId = firstRun.currentSessionId
        let savedSessionStart = firstRun.currentSessionStart

        // At the next launch, reading the saved starts blocks until the test lets it go
        let relaunch = try buildSession(relaunching: firstRun)
        let nextRun = relaunch.session
        let storage = relaunch.storage
        let eventManager = relaunch.eventManager
        let readBlocked = expectation(description: "read of the saved starts blocked")
        storage.didBlockRead = { readBlocked.fulfill() }

        defer {
            storage.unblock()
            nextRun.heldSessionStarts.waitForRequestedSaves()
        }

        // Scheduling the session start does not wait for the read, and the session id can be read
        nextRun.scheduleSessionStart()
        wait(for: [readBlocked], timeout: arrivalTimeout)
        XCTAssertEqual(storage.finishedHeldStartReads, 0)
        XCTAssertNotEqual(nextRun.currentSessionId, savedSessionId)

        // The saved session's late telemetry, such as its crash report, does not send its start yet
        nextRun.trackAcceptedTelemetry(forSessionId: savedSessionId)
        waitForAccessQueue(of: nextRun)
        XCTAssertTrue(sessionStarts(sentBy: eventManager).isEmpty)

        // Once the read finishes, the start is sent as it was when its session started
        let sent = expectSessionStarts(from: eventManager, sessionIds: [savedSessionId])
        storage.unblock()
        wait(for: [sent], timeout: arrivalTimeout)
        nextRun.waitForHeldStartRestoration()

        let starts = sessionStarts(sentBy: eventManager)
        XCTAssertEqual(starts.count, 1)

        let event = try XCTUnwrap(starts.first)
        XCTAssertEqual(event.sessionId, savedSessionId)
        XCTAssertEqual(event.timestamp, savedSessionStart)
        XCTAssertEqual(event.attributes?["session.previous_id"], .string(replacedSessionId))
        XCTAssertEqual(event.attributes?["screen.name"], .string("RotatedScreen"))
    }

    func testActivityDuringRestoringIsAppliedOnceItFinishes() throws {
        // The previous run ends while holding its session's start
        let (firstRun, _) = try buildSession(named: "heldStartActivityDuringRestoreTest")
        firstRun.scheduleSessionStart()
        let savedSessionId = firstRun.currentSessionId
        firstRun.waitForHeldStartRestoration()
        firstRun.heldSessionStarts.waitForRequestedSaves()
        let savedRecords = firstRun.heldSessionStarts.load()

        let relaunch = try buildSession(relaunching: firstRun)
        let nextRun = relaunch.session
        let storage = relaunch.storage
        let eventManager = relaunch.eventManager
        let readBlocked = expectation(description: "read of the saved starts blocked")
        storage.didBlockRead = { readBlocked.fulfill() }

        defer {
            storage.unblock()
            nextRun.heldSessionStarts.waitForRequestedSaves()
        }

        nextRun.scheduleSessionStart()
        wait(for: [readBlocked], timeout: arrivalTimeout)

        // While the read is blocked, telemetry of the new and of the saved session arrives, and the session rotates
        let currentSessionId = nextRun.currentSessionId
        nextRun.trackAcceptedTelemetry(forSessionId: currentSessionId)
        nextRun.trackAcceptedTelemetry(forSessionId: savedSessionId)
        nextRun.trackAcceptedTelemetry(forSessionId: savedSessionId)
        nextRun.rotateSession()
        let rotatedSessionId = nextRun.currentSessionId
        waitForAccessQueue(of: nextRun)

        // No start is sent yet, and no save was written over the saved starts before the read
        XCTAssertTrue(sessionStarts(sentBy: eventManager).isEmpty)
        XCTAssertEqual(storage.writtenHeldStartSaves, 0)
        XCTAssertEqual(try storage.storedHeldStarts(), savedRecords)

        // Once the read finishes, each start with telemetry is sent once
        let sent = expectSessionStarts(from: eventManager, sessionIds: [currentSessionId, savedSessionId])
        storage.unblock()
        wait(for: [sent], timeout: arrivalTimeout)
        nextRun.waitForHeldStartRestoration()

        let sentSessionIds = sessionStarts(sentBy: eventManager).compactMap(\.sessionId)
        XCTAssertEqual(sentSessionIds.sorted(), [currentSessionId, savedSessionId].sorted())

        // Only the rotated session's start, which still waits for telemetry, stays saved
        nextRun.heldSessionStarts.waitForRequestedSaves()
        XCTAssertEqual(nextRun.heldSessionStarts.load().map(\.sessionId), [rotatedSessionId])
    }


    // MARK: - Failed read

    func testFailedReadRestoresNothingAndSessionStartStillWorks() throws {
        // A start is saved, but reading the saved starts fails
        let name = "heldStartFailedReadTest"
        let savedStorage = DefaultSessionTestBuilder.buildCleanHeldStartsStorage(named: name)
        let savedSessionId = "0123456789abcdef0123456789abcdef"
        let savedStart = HeldSessionStartRecord(sessionId: savedSessionId, start: Date(), previousSessionId: nil, screenName: nil)
        try savedStorage.update([savedStart], forKey: HeldSessionStartStore.storageKey)

        let sessionsModel = SessionsModel(storage: UserDefaultsStorageTestBuilder.buildCleanStorage(named: name))
        let heldSessionStarts = HeldSessionStartStore(storage: FailingHeldStartReadStorage(wrapping: savedStorage))
        let (session, eventManager) = try link(DefaultSession(sessionsModel: sessionsModel, heldSessionStarts: heldSessionStarts))

        // The new session's start is released by its telemetry as usual
        session.scheduleSessionStart()
        let sessionId = session.currentSessionId

        let sent = expectSessionStarts(from: eventManager, sessionIds: [sessionId])
        session.trackAcceptedTelemetry(forSessionId: sessionId)
        wait(for: [sent], timeout: arrivalTimeout)

        // The saved start is not restored, so its session's telemetry sends nothing
        session.trackAcceptedTelemetry(forSessionId: savedSessionId)
        session.waitForHeldStartRestoration()

        XCTAssertEqual(sessionStarts(sentBy: eventManager).compactMap(\.sessionId), [sessionId])

        session.heldSessionStarts.waitForRequestedSaves()
        let stillSaved: [HeldSessionStartRecord]? = try savedStorage.read(forKey: HeldSessionStartStore.storageKey)
        XCTAssertEqual(stillSaved, [])
    }


    // MARK: - Helpers

    /// The session of the next run of the app, with its storage and event manager.
    private struct Relaunch {
        let session: DefaultSession
        let storage: BlockingHeldStartStorage
        let eventManager: MockEventManager
    }

    /// Builds a session with clean storage, linked to an agent whose event manager records sent events.
    private func buildSession(named name: String) throws -> (DefaultSession, MockEventManager) {
        try link(DefaultSessionTestBuilder.build(named: name))
    }

    /// Builds the session of the next run of the app on the same storage as `previous`.
    ///
    /// It is built after `previous` finished restoring and the saves it requested are written. Its reads
    /// of the held starts block until the test unblocks them.
    private func buildSession(relaunching previous: DefaultSession) throws -> Relaunch {
        previous.waitForHeldStartRestoration()
        previous.heldSessionStarts.waitForRequestedSaves()

        let sessionsModel = SessionsModel(storage: previous.sessionsModel.storage)
        let storage = BlockingHeldStartStorage(wrapping: previous.heldSessionStarts.storage, blocking: .read)
        let heldSessionStarts = HeldSessionStartStore(storage: storage)
        let (session, eventManager) = try link(DefaultSession(sessionsModel: sessionsModel, heldSessionStarts: heldSessionStarts))

        return Relaunch(session: session, storage: storage, eventManager: eventManager)
    }

    /// Waits until the session has done the work queued on its access queue so far.
    ///
    /// The access queue is serial and reading the current session id waits for it. While the read of
    /// the saved starts is blocked, the restoring cannot finish, so a check after this wait does not
    /// depend on timing.
    private func waitForAccessQueue(of session: DefaultSession) {
        _ = session.currentSessionId
    }

    private func link(_ session: DefaultSession) throws -> (DefaultSession, MockEventManager) {
        let configuration = try ConfigurationTestBuilder.buildDefault()
        let agent = try AgentTestBuilder.build(with: configuration, session: session)
        session.owner = agent

        // The event manager registers its pipeline as the global one, where spans that other tests leave
        // running would end with this session's id and release its held starts. The globals are put back.
        let globals = OpenTelemetryGlobals()
        let eventManager = try MockEventManager(with: configuration, agent: agent)
        globals.restore()
        agent.eventManager = eventManager
        retainedAgents.append(agent)
        stopAtTeardown(agent)

        return (session, eventManager)
    }

    /// Returns an expectation fulfilled when the event manager has sent the starts of all the given sessions.
    private func expectSessionStarts(from eventManager: MockEventManager, sessionIds: Set<String>) -> XCTestExpectation {
        let sent = expectation(description: "session.start events sent")
        let lock = NSLock()
        var waitingSessionIds = sessionIds

        eventManager.sentEventHandler = { event in
            guard event.name == "session.start", let sessionId = event.sessionId else {
                return
            }

            let isLast = lock.withLock {
                waitingSessionIds.remove(sessionId) != nil && waitingSessionIds.isEmpty
            }

            if isLast {
                sent.fulfill()
            }
        }

        return sent
    }

    private func sessionStarts(sentBy eventManager: MockEventManager) -> [AgentEvent] {
        eventManager.sentEvents.filter { $0.name == "session.start" }
    }
}
