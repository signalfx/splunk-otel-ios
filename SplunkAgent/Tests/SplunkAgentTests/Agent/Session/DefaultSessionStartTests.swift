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

import CiscoSessionReplay
import OpenTelemetryApi
import OpenTelemetrySdk
import SplunkCommon
import XCTest

@testable import SplunkAgent
@testable import SplunkOpenTelemetry

final class DefaultSessionStartTests: XCTestCase {

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
        restoreOpenTelemetryGlobalsAtTeardown()
    }

    override func tearDown() {
        retainedAgents = []

        super.tearDown()
    }


    // MARK: - Held session start

    func testSessionStartIsHeldUntilAcceptedTelemetry() throws {
        let (defaultSession, eventManager) = try buildSession(named: "heldSessionStartTest")
        defaultSession.scheduleSessionStart()

        // Tracked activity alone does not release the session start
        defaultSession.trackActivity(at: Date())
        waitForQueuedWork(of: defaultSession)
        XCTAssertTrue(sessionStarts(sentBy: eventManager).isEmpty)

        // Accepted telemetry releases it, with the session's own start and no previous session
        let sent = expectSessionStart(from: eventManager)
        defaultSession.trackAcceptedTelemetry(forSessionId: defaultSession.currentSessionId)
        wait(for: [sent], timeout: arrivalTimeout)

        let event = try XCTUnwrap(eventManager.sentEvents.first)
        XCTAssertEqual(event.sessionId, defaultSession.currentSessionId)
        XCTAssertEqual(event.timestamp, defaultSession.currentSessionStart)
        XCTAssertNil(event.attributes?["session.previous_id"])

        // Further telemetry does not repeat it
        defaultSession.trackAcceptedTelemetry(forSessionId: defaultSession.currentSessionId)
        waitForQueuedWork(of: defaultSession)

        XCTAssertEqual(eventManager.sentEvents.count, 1)
    }

    func testSessionStartIgnoresTelemetryOfOtherSession() throws {
        let (defaultSession, eventManager) = try buildSession(named: "otherSessionStartTest")
        defaultSession.scheduleSessionStart()

        defaultSession.trackAcceptedTelemetry(forSessionId: "some-other-session")
        waitForQueuedWork(of: defaultSession)

        XCTAssertTrue(sessionStarts(sentBy: eventManager).isEmpty)
    }


    // MARK: - Rotation

    func testRotationKeepsStartOfReplacedSessionForLateTelemetry() throws {
        let (defaultSession, eventManager) = try buildSession(named: "rotationKeepTest")
        defaultSession.scheduleSessionStart()
        let replacedSessionId = defaultSession.currentSessionId

        // The new session starts on screen A, and its first telemetry comes from screen B
        defaultSession.owner?.runtimeAttributes.updateScreenName("ScreenA")
        defaultSession.rotateSession()
        defaultSession.owner?.runtimeAttributes.updateScreenName("ScreenB")

        // The new session sends its own start first, not linked to the replaced session,
        // and with the screen shown when it started
        let sent = expectSessionStart(from: eventManager)
        defaultSession.trackAcceptedTelemetry(forSessionId: defaultSession.currentSessionId)
        wait(for: [sent], timeout: arrivalTimeout)

        let event = try XCTUnwrap(eventManager.sentEvents.first)
        XCTAssertEqual(event.sessionId, defaultSession.currentSessionId)
        XCTAssertNil(event.attributes?["session.previous_id"])
        XCTAssertEqual(event.attributes?["screen.name"], .string("ScreenA"))

        // A long-running span of the replaced session ends later, whatever time has passed,
        // and still releases the replaced session's start
        Thread.sleep(forTimeInterval: 0.3)

        let sentForReplaced = expectSessionStart(from: eventManager)
        defaultSession.trackAcceptedTelemetry(forSessionId: replacedSessionId)
        wait(for: [sentForReplaced], timeout: arrivalTimeout)

        XCTAssertEqual(eventManager.sentEvents.last?.sessionId, replacedSessionId)
    }

    func testOldestHeldSessionStartIsDroppedBeyondLimit() throws {
        let (defaultSession, eventManager) = try buildSession(named: "heldLimitTest")
        defaultSession.scheduleSessionStart()
        let oldestSessionId = defaultSession.currentSessionId

        // Rotate until the oldest start is pushed out, none of the sessions producing telemetry
        for _ in 0 ..< DefaultSession.maxHeldSessionStarts {
            defaultSession.rotateSession()
        }

        defaultSession.trackAcceptedTelemetry(forSessionId: oldestSessionId)
        waitForQueuedWork(of: defaultSession)
        XCTAssertTrue(sessionStarts(sentBy: eventManager).isEmpty)

        // The newest held start is still released
        let sent = expectSessionStart(from: eventManager)
        defaultSession.trackAcceptedTelemetry(forSessionId: defaultSession.currentSessionId)
        wait(for: [sent], timeout: arrivalTimeout)

        XCTAssertEqual(eventManager.sentEvents.first?.sessionId, defaultSession.currentSessionId)
    }

    func testTelemetryExportedAfterRotationReleasesStartOfReplacedSession() throws {
        let (defaultSession, eventManager) = try buildSession(named: "rotationLateTelemetryTest")
        defaultSession.scheduleSessionStart()

        let replacedSessionId = defaultSession.currentSessionId
        let replacedSessionStart = defaultSession.currentSessionStart

        defaultSession.owner?.runtimeAttributes.updateScreenName("ScreenA")
        defaultSession.rotateSession()

        // Telemetry of the replaced session, buffered before the rotation, is exported afterwards
        let sentForReplaced = expectSessionStart(from: eventManager)
        defaultSession.trackAcceptedTelemetry(forSessionId: replacedSessionId)
        wait(for: [sentForReplaced], timeout: arrivalTimeout)

        let replacedEvent = try XCTUnwrap(eventManager.sentEvents.first)
        XCTAssertEqual(replacedEvent.sessionId, replacedSessionId)
        XCTAssertEqual(replacedEvent.timestamp, replacedSessionStart)

        // The new session still sends its own start
        let sentForCurrent = expectSessionStart(from: eventManager)
        defaultSession.trackAcceptedTelemetry(forSessionId: defaultSession.currentSessionId)
        wait(for: [sentForCurrent], timeout: arrivalTimeout)

        XCTAssertEqual(eventManager.sentEvents.count, 2)
        XCTAssertEqual(eventManager.sentEvents.last?.sessionId, defaultSession.currentSessionId)
    }

    func testSessionTooLongRotatesWithLinkedPreviousSession() throws {
        let (defaultSession, eventManager) = try buildSession(named: "sessionTooLongTest")
        let previousSessionId = defaultSession.currentSessionId

        // Let the periodic refresh rotate the session once
        defaultSession.testMaxSessionLength = 0.5
        let rotated = expectation(forNotification: DefaultSession.sessionDidResetNotification, object: nil) { _ in
            // Sessions of other tests post the same notification
            guard defaultSession.currentSessionId != previousSessionId else {
                return false
            }

            defaultSession.testMaxSessionLength = nil

            return true
        }
        wait(for: [rotated], timeout: arrivalTimeout)

        let sent = expectSessionStart(from: eventManager)
        defaultSession.trackAcceptedTelemetry(forSessionId: defaultSession.currentSessionId)
        wait(for: [sent], timeout: arrivalTimeout)

        let event = try XCTUnwrap(eventManager.sentEvents.first)
        XCTAssertEqual(event.sessionId, defaultSession.currentSessionId)
        XCTAssertEqual(event.attributes?["session.previous_id"], .string(previousSessionId))
    }


    // MARK: - Through the real pipelines

    func testExportedSpanReleasesSessionStart() throws {
        let (defaultSession, eventManager) = try buildSession(named: "pipelineReleaseTest")
        defaultSession.scheduleSessionStart()

        let sent = expectSessionStart(from: eventManager)
        try exportSpan(through: eventManager)
        wait(for: [sent], timeout: arrivalTimeout)

        XCTAssertEqual(eventManager.sentEvents.first?.sessionId, defaultSession.currentSessionId)
    }

    func testSpanDroppedByInterceptorDoesNotReleaseSessionStart() throws {
        let (defaultSession, eventManager) = try buildSession(named: "pipelineDroppedTest", interceptor: { _ in nil })
        defaultSession.scheduleSessionStart()

        // The export has finished when this returns, so the drop has been decided
        try exportSpan(through: eventManager)
        waitForQueuedWork(of: defaultSession)

        XCTAssertTrue(sessionStarts(sentBy: eventManager).isEmpty)
    }

    func testReleasedSessionStartIsSavedBeforeNextBatchExport() throws {
        let saved = expectation(description: "session.start exported")
        let (defaultSession, eventManager) = try buildSession(
            named: "persistedReleaseTest",
            interceptor: { span in
                if span.name == "session.start" {
                    saved.fulfill()
                }

                return span
            },
            eventManagerType: DefaultEventManager.self
        )
        defaultSession.scheduleSessionStart()

        try exportSpan(through: eventManager)

        // Batches are exported once a second, so the start arrives sooner only if it was saved right away
        wait(for: [saved], timeout: 0.5)
    }

    func testIndexedReplayDataReleasesSessionStart() throws {
        let (defaultSession, eventManager) = try buildSession(named: "replayReleaseTest")
        eventManager.sessionReplayIndexer = MockEventIndexer(isReady: true)
        defaultSession.scheduleSessionStart()

        let sent = expectSessionStart(from: eventManager)
        publishReplayData(through: eventManager, after: defaultSession.currentSessionStart)
        wait(for: [sent], timeout: arrivalTimeout)

        // Replay data also sends an isRecording event, so find the start event by name
        let event = try XCTUnwrap(eventManager.sentEvents.first { $0.name == "session.start" })
        XCTAssertEqual(event.sessionId, defaultSession.currentSessionId)
    }

    func testReplayDataNotIndexedDoesNotReleaseSessionStart() throws {
        let (defaultSession, eventManager) = try buildSession(named: "replayNotIndexedTest")
        eventManager.sessionReplayIndexer = MockEventIndexer(isReady: false)
        defaultSession.scheduleSessionStart()

        // This covers the replay data only. Its isRecording event is a span too, and in the agent it can
        // release the start even when indexing fails; MockEventManager records that event instead of sending it.
        let rejected = expectation(description: "replay data not indexed")
        publishReplayData(through: eventManager, after: defaultSession.currentSessionStart) { processed in
            XCTAssertFalse(processed)
            rejected.fulfill()
        }
        wait(for: [rejected], timeout: arrivalTimeout)
        waitForQueuedWork(of: defaultSession)

        XCTAssertTrue(sessionStarts(sentBy: eventManager).isEmpty)
    }


    // MARK: - Helpers

    /// Builds a session linked to an agent whose event manager records sent events.
    private func buildSession(
        named name: String,
        interceptor: ((SpanData) -> SpanData?)? = nil
    ) throws -> (DefaultSession, MockEventManager) {
        try buildSession(named: name, interceptor: interceptor, eventManagerType: MockEventManager.self)
    }

    /// Builds a session linked to an agent with an event manager of the given type.
    private func buildSession<Manager: DefaultEventManager>(
        named name: String,
        interceptor: ((SpanData) -> SpanData?)?,
        eventManagerType _: Manager.Type
    ) throws -> (DefaultSession, Manager) {
        let configuration = try ConfigurationTestBuilder.buildDefault().spanInterceptor(interceptor)
        let defaultSession = try DefaultSessionTestBuilder.build(named: name)
        let agent = try AgentTestBuilder.build(with: configuration, session: defaultSession)
        defaultSession.owner = agent

        // The event manager registers its pipeline as the global one. Instrumentation that other tests
        // left running (for example their remote configuration requests) would then end spans in this
        // pipeline, with this session's ID, and release its held starts. So the globals are put back.
        let globals = OpenTelemetryGlobals()
        let eventManager = try Manager(with: configuration, agent: agent)
        globals.restore()
        agent.eventManager = eventManager
        retainedAgents.append(agent)
        stopAtTeardown(agent)

        return (defaultSession, eventManager)
    }

    /// Returns an expectation fulfilled when the event manager sends a session start event.
    private func expectSessionStart(from eventManager: MockEventManager) -> XCTestExpectation {
        let sessionStart = expectation(description: "session.start sent")

        eventManager.sentEventHandler = { event in
            if event.name == "session.start" {
                sessionStart.fulfill()
            }
        }

        return sessionStart
    }

    /// Waits until the session has finished restoring the saved held starts and done the work queued
    /// on its access queue so far.
    ///
    /// Releases that come while the saved starts are restored wait for the restoring, so a check that a
    /// start was not sent must come after it. The mock event manager records sent events at once, so a
    /// check after this wait does not depend on timing.
    private func waitForQueuedWork(of session: DefaultSession) {
        session.waitForHeldStartRestoration()
    }

    /// The session start events the event manager sent so far.
    private func sessionStarts(sentBy eventManager: MockEventManager) -> [AgentEvent] {
        eventManager.sentEvents.filter { $0.name == "session.start" }
    }

    /// Ends one span on the event manager's tracer and waits until it is exported.
    ///
    /// When this returns, the span has passed the interceptor, so the session has been told about it if it was kept.
    private func exportSpan(through eventManager: DefaultEventManager) throws {
        let traceProcessor = eventManager.concreteTraceProcessor
        let tracer = traceProcessor.tracerProvider.get(instrumentationName: "test")

        tracer.spanBuilder(spanName: "span").startSpan().end()

        // A force flush from the main thread doesn't wait, so wait for the write to finish
        let exported = expectation(description: "span exported")
        traceProcessor.persistBufferedSpans(timeout: 5) { _ in
            exported.fulfill()
        }
        wait(for: [exported], timeout: arrivalTimeout)
    }

    /// Publishes Session Replay data recorded just after the session started.
    private func publishReplayData(
        through eventManager: DefaultEventManager,
        after sessionStart: Date,
        completion: @escaping (Bool) -> Void = { _ in }
    ) {
        // Replay data is matched to a session by time, so it starts just after the session did
        let startMs = Int((sessionStart.timeIntervalSince1970 + 0.01) * 1_000.0)
        let metadata = Metadata(startUnixMs: startMs, endUnixMs: startMs + 1)

        eventManager.publish(data: Data([0]), metadata: metadata, completion: completion)
    }
}
