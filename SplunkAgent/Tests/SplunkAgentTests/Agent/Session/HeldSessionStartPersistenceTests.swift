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

import OpenTelemetryApi
import SplunkCommon
import XCTest

@testable import SplunkAgent

/// Tests that a held session start survives the end of the app's process.
///
/// Each test simulates a relaunch: a second session object on the same storage, as at the next launch.
final class HeldSessionStartPersistenceTests: XCTestCase {

    // MARK: - Private

    /// Keeps agents alive, as a session only holds an unowned reference to its agent.
    private var retainedAgents: [SplunkRum] = []

    /// Waiting time for an event that must be sent.
    ///
    /// The wait ends as soon as the event comes, so a generous limit costs nothing when the code works,
    /// and a slow or stalled test machine does not fail the test.
    private let arrivalTimeout: TimeInterval = 10


    // MARK: - Setup

    override func setUp() {
        super.setUp()

        retainedAgents = []
    }

    override func tearDown() {
        retainedAgents = []

        super.tearDown()
    }


    // MARK: - Relaunch

    func testStartOfCrashedSessionIsSentWithItsLateTelemetryAfterRelaunch() throws {
        // The session holds its start, and the app ends before any of its telemetry is accepted
        let (firstRun, _) = try buildSession(named: "heldStartRelaunchTest")
        firstRun.owner?.runtimeAttributes.updateScreenName("LaunchScreen")
        firstRun.scheduleSessionStart()

        let crashedSessionId = firstRun.currentSessionId
        let crashedSessionStart = firstRun.currentSessionStart

        // At the next launch, the crashed session's crash report is accepted for export
        let (nextRun, eventManager) = try buildSession(relaunching: firstRun)
        nextRun.owner?.runtimeAttributes.updateScreenName("OtherScreen")
        nextRun.scheduleSessionStart()
        XCTAssertNotEqual(nextRun.currentSessionId, crashedSessionId)

        let sent = expectSessionStart(from: eventManager, sessionId: crashedSessionId)
        nextRun.trackAcceptedTelemetry(forSessionId: crashedSessionId)
        wait(for: [sent], timeout: arrivalTimeout)

        // The start is the crashed session's own, as it was when that session started
        let event = try XCTUnwrap(sessionStart(sentBy: eventManager, sessionId: crashedSessionId))
        XCTAssertEqual(event.timestamp, crashedSessionStart)
        XCTAssertNil(event.attributes?["session.previous_id"])
        XCTAssertEqual(event.attributes?["screen.name"], .string("LaunchScreen"))

        // The new session's start still waits for the new session's own telemetry
        XCTAssertNil(sessionStart(sentBy: eventManager, sessionId: nextRun.currentSessionId))
    }

    func testReleasedStartIsNotSentAgainAfterRelaunch() throws {
        let (firstRun, firstEventManager) = try buildSession(named: "heldStartReleasedTest")
        firstRun.scheduleSessionStart()
        let sessionId = firstRun.currentSessionId

        let sent = expectSessionStart(from: firstEventManager, sessionId: sessionId)
        firstRun.trackAcceptedTelemetry(forSessionId: sessionId)
        wait(for: [sent], timeout: arrivalTimeout)

        // Late telemetry of the same session at the next launch does not send its start again
        let (nextRun, eventManager) = try buildSession(relaunching: firstRun)
        nextRun.scheduleSessionStart()

        nextRun.trackAcceptedTelemetry(forSessionId: sessionId)
        waitForQueuedWork(of: nextRun)

        XCTAssertNil(sessionStart(sentBy: eventManager, sessionId: sessionId))
    }

    func testRotatedSessionStartKeepsItsPreviousSessionAfterRelaunch() throws {
        let (firstRun, _) = try buildSession(named: "heldStartRotationTest")
        firstRun.scheduleSessionStart()

        let replacedSessionId = firstRun.currentSessionId
        firstRun.rotateSession(previousSessionId: replacedSessionId)
        let rotatedSessionId = firstRun.currentSessionId

        let (nextRun, eventManager) = try buildSession(relaunching: firstRun)
        nextRun.scheduleSessionStart()

        let sent = expectSessionStart(from: eventManager, sessionId: rotatedSessionId)
        nextRun.trackAcceptedTelemetry(forSessionId: rotatedSessionId)
        wait(for: [sent], timeout: arrivalTimeout)

        let event = try XCTUnwrap(sessionStart(sentBy: eventManager, sessionId: rotatedSessionId))
        XCTAssertEqual(event.attributes?["session.previous_id"], .string(replacedSessionId))
    }

    func testRelaunchKeepsNewestHeldStartsWithinLimit() throws {
        // The previous run ends while holding as many starts as allowed
        let (firstRun, _) = try buildSession(named: "heldStartLimitTest")
        firstRun.scheduleSessionStart()
        var sessionIds = [firstRun.currentSessionId]

        for _ in 1 ..< DefaultSession.maxHeldSessionStarts {
            firstRun.rotateSession()
            sessionIds.append(firstRun.currentSessionId)
        }

        // The new session's own start pushes out the oldest restored start
        let (nextRun, eventManager) = try buildSession(relaunching: firstRun)
        nextRun.scheduleSessionStart()

        let oldestSessionId = try XCTUnwrap(sessionIds.first)
        nextRun.trackAcceptedTelemetry(forSessionId: oldestSessionId)
        waitForQueuedWork(of: nextRun)

        XCTAssertNil(sessionStart(sentBy: eventManager, sessionId: oldestSessionId))

        let newestSessionId = try XCTUnwrap(sessionIds.last)
        let sent = expectSessionStart(from: eventManager, sessionId: newestSessionId)
        nextRun.trackAcceptedTelemetry(forSessionId: newestSessionId)
        wait(for: [sent], timeout: arrivalTimeout)
    }

    func testUnreadableSavedStartsAreIgnored() throws {
        let (firstRun, _) = try buildSession(named: "heldStartUnreadableTest")
        firstRun.sessionsModel.heldSessionStarts.waitForRequestedSaves()
        try firstRun.sessionsModel.storage.update("not a list of starts", forKey: HeldSessionStartStore.storageKey)

        // The next run restores nothing, and its own session start still works
        let (nextRun, eventManager) = try buildSession(relaunching: firstRun)
        nextRun.scheduleSessionStart()

        let sent = expectSessionStart(from: eventManager, sessionId: nextRun.currentSessionId)
        nextRun.trackAcceptedTelemetry(forSessionId: nextRun.currentSessionId)
        wait(for: [sent], timeout: arrivalTimeout)
    }


    // MARK: - Slow storage

    func testReleaseAndSessionIdDoNotWaitForStorage() throws {
        // Saving the held starts blocks until the test lets it go, as a stalled storage call can
        let storage = BlockingHeldStartStorage(
            wrapping: UserDefaultsStorageTestBuilder.buildCleanStorage(named: "heldStartBlockedStorageTest")
        )
        let (session, eventManager) = try link(DefaultSession(sessionsModel: SessionsModel(storage: storage)))

        defer {
            storage.unblock()
            session.sessionsModel.heldSessionStarts.waitForRequestedSaves()
        }

        // The session id can still be read, and the held start is still released and sent
        session.scheduleSessionStart()
        let sessionId = session.currentSessionId

        let sent = expectSessionStart(from: eventManager, sessionId: sessionId)
        session.trackAcceptedTelemetry(forSessionId: sessionId)
        wait(for: [sent], timeout: arrivalTimeout)

        // None of the saves was written while the start was held and sent
        XCTAssertEqual(storage.writtenHeldStartSaves, 0)
    }


    // MARK: - Storage notifications

    func testSessionIdCanBeReadInDefaultsObserverWhileHeldStartsAreSaved() throws {
        let (session, eventManager) = try buildSession(named: "heldStartObserverTest")

        // `UserDefaults` posts this notification synchronously on the thread that saves the held starts.
        // App code can observe it and read the session id there, for example by starting a span.
        let lock = NSLock()
        var didRead = false
        let read = expectation(description: "session id read in a defaults observer")

        let observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: nil
        ) { _ in
            _ = session.currentSessionId

            let isFirstRead = lock.withLock {
                defer { didRead = true }

                return !didRead
            }

            if isFirstRead {
                read.fulfill()
            }
        }

        defer {
            NotificationCenter.default.removeObserver(observer)
        }

        // Holding, rotating and releasing all save the held starts
        session.scheduleSessionStart()
        session.rotateSession()

        let sent = expectSessionStart(from: eventManager, sessionId: session.currentSessionId)
        session.trackAcceptedTelemetry(forSessionId: session.currentSessionId)
        wait(for: [read, sent], timeout: arrivalTimeout)

        session.sessionsModel.heldSessionStarts.waitForRequestedSaves()
    }


    // MARK: - Helpers

    /// Builds a session with clean storage, linked to an agent whose event manager records sent events.
    private func buildSession(named name: String) throws -> (DefaultSession, MockEventManager) {
        try link(DefaultSessionTestBuilder.build(named: name))
    }

    /// Builds the session of the next run of the app: a new session object on the same storage as `previous`,
    /// after the saves that `previous` requested are written.
    private func buildSession(relaunching previous: DefaultSession) throws -> (DefaultSession, MockEventManager) {
        previous.sessionsModel.heldSessionStarts.waitForRequestedSaves()

        return try link(DefaultSession(sessionsModel: SessionsModel(storage: previous.sessionsModel.storage)))
    }

    /// Waits until the session has done the work queued on its access queue so far.
    ///
    /// The access queue is serial and reading the current session id waits for it, so the read returns
    /// after the queued work. The mock event manager records sent events at once, so a check after
    /// this wait does not depend on timing.
    private func waitForQueuedWork(of session: DefaultSession) {
        _ = session.currentSessionId
    }

    private func link(_ session: DefaultSession) throws -> (DefaultSession, MockEventManager) {
        let configuration = try ConfigurationTestBuilder.buildDefault()
        let agent = try AgentTestBuilder.build(with: configuration, session: session)
        session.owner = agent

        // The event manager registers its pipeline as the global one, where spans that other tests leave
        // running would end with this session's id and release its held starts. The globals are put back.
        let tracerProvider = OpenTelemetry.instance.tracerProvider
        let loggerProvider = OpenTelemetry.instance.loggerProvider
        let eventManager = try MockEventManager(with: configuration, agent: agent)
        OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)
        OpenTelemetry.registerLoggerProvider(loggerProvider: loggerProvider)
        agent.eventManager = eventManager
        retainedAgents.append(agent)

        return (session, eventManager)
    }

    /// Returns an expectation fulfilled when the event manager sends the start of the given session.
    private func expectSessionStart(from eventManager: MockEventManager, sessionId: String) -> XCTestExpectation {
        let sessionStart = expectation(description: "session.start sent")

        eventManager.sentEventHandler = { event in
            if event.name == "session.start", event.sessionId == sessionId {
                sessionStart.fulfill()
            }
        }

        return sessionStart
    }

    private func sessionStart(sentBy eventManager: MockEventManager, sessionId: String) -> AgentEvent? {
        eventManager.sentEvents.first { $0.name == "session.start" && $0.sessionId == sessionId }
    }
}


/// A storage whose saves of the held session starts block until the test unblocks them.
///
/// Other keys pass through at once. A blocked save gives up after a while, so that a regression fails
/// the test instead of hanging it.
private final class BlockingHeldStartStorage: KeyValueStorage {

    // MARK: - Private

    private let storage: KeyValueStorage
    private let gate = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var isBlocking = true
    private var writtenSaves = 0


    // MARK: - Recorded saves

    /// The number of saves of the held session starts written so far.
    var writtenHeldStartSaves: Int {
        lock.withLock { writtenSaves }
    }


    // MARK: - Initialization

    init(wrapping storage: KeyValueStorage) {
        self.storage = storage
    }


    // MARK: - Blocking

    /// Lets the blocked saves and all later saves through.
    func unblock() {
        let wasBlocking = lock.withLock {
            defer { isBlocking = false }

            return isBlocking
        }

        if wasBlocking {
            gate.signal()
        }
    }


    // MARK: - CRUD operations

    func insert(_ value: Codable, forKey key: String) throws {
        try storage.insert(value, forKey: key)
    }

    func read<T: Codable>(forKey key: String) throws -> T? {
        try storage.read(forKey: key)
    }

    func update(_ value: Codable, forKey key: String) throws {
        if key == HeldSessionStartStore.storageKey, lock.withLock({ isBlocking }) {
            // One blocked save at a time: the store writes in order on its own serial queue
            _ = gate.wait(timeout: .now() + 20)
            gate.signal()
        }

        try storage.update(value, forKey: key)

        if key == HeldSessionStartStore.storageKey {
            lock.withLock { writtenSaves += 1 }
        }
    }

    func delete(forKey key: String) throws {
        try storage.delete(forKey: key)
    }
}
