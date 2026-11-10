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

    /// Waiting time for asserting that an event is not sent.
    private let absenceTimeout: TimeInterval = 0.3


    // MARK: - Setup

    override func setUp() {
        super.setUp()

        retainedAgents = []
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
        let notSentForActivity = expectSessionStart(from: eventManager, isInverted: true)
        defaultSession.trackActivity(at: Date())
        wait(for: [notSentForActivity], timeout: absenceTimeout)

        // Accepted telemetry releases it, with the session's own start and no previous session
        let sent = expectSessionStart(from: eventManager)
        defaultSession.trackAcceptedTelemetry(forSessionId: defaultSession.currentSessionId)
        wait(for: [sent], timeout: 1)

        let event = try XCTUnwrap(eventManager.sentEvents.first)
        XCTAssertEqual(event.sessionId, defaultSession.currentSessionId)
        XCTAssertEqual(event.timestamp, defaultSession.currentSessionStart)
        XCTAssertNil(event.attributes?["session.previous_id"])

        // Further telemetry does not repeat it
        let notRepeated = expectSessionStart(from: eventManager, isInverted: true)
        defaultSession.trackAcceptedTelemetry(forSessionId: defaultSession.currentSessionId)
        wait(for: [notRepeated], timeout: absenceTimeout)

        XCTAssertEqual(eventManager.sentEvents.count, 1)
    }

    func testSessionStartIgnoresTelemetryOfOtherSession() throws {
        let (defaultSession, eventManager) = try buildSession(named: "otherSessionStartTest")
        defaultSession.scheduleSessionStart()

        let notSent = expectSessionStart(from: eventManager, isInverted: true)
        defaultSession.trackAcceptedTelemetry(forSessionId: "some-other-session")

        wait(for: [notSent], timeout: absenceTimeout)
    }


    // MARK: - Rotation

    func testRotationDropsStartOfSessionWithoutTelemetry() throws {
        let (defaultSession, eventManager) = try buildSession(named: "rotationDropTest")
        defaultSession.scheduleSessionStart()
        let abandonedSessionId = defaultSession.currentSessionId

        // The new session starts on screen A, and its first telemetry comes from screen B
        defaultSession.owner?.runtimeAttributes.updateScreenName("ScreenA")
        defaultSession.rotateSession()
        defaultSession.owner?.runtimeAttributes.updateScreenName("ScreenB")

        // The abandoned session produced nothing, so its start is dropped
        let notSent = expectSessionStart(from: eventManager, isInverted: true)
        defaultSession.trackAcceptedTelemetry(forSessionId: abandonedSessionId)
        wait(for: [notSent], timeout: absenceTimeout)

        // The new session sends its own start, not linked to the abandoned session
        let sent = expectSessionStart(from: eventManager)
        defaultSession.trackAcceptedTelemetry(forSessionId: defaultSession.currentSessionId)
        wait(for: [sent], timeout: 1)

        let event = try XCTUnwrap(eventManager.sentEvents.first)
        XCTAssertEqual(event.sessionId, defaultSession.currentSessionId)
        XCTAssertNil(event.attributes?["session.previous_id"])
        XCTAssertEqual(event.attributes?["screen.name"], .string("ScreenA"))
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
        wait(for: [rotated], timeout: 5)

        let sent = expectSessionStart(from: eventManager)
        defaultSession.trackAcceptedTelemetry(forSessionId: defaultSession.currentSessionId)
        wait(for: [sent], timeout: 1)

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
        wait(for: [sent], timeout: 1)

        XCTAssertEqual(eventManager.sentEvents.first?.sessionId, defaultSession.currentSessionId)
    }

    func testSpanDroppedByInterceptorDoesNotReleaseSessionStart() throws {
        let (defaultSession, eventManager) = try buildSession(named: "pipelineDroppedTest", interceptor: { _ in nil })
        defaultSession.scheduleSessionStart()

        let notSent = expectSessionStart(from: eventManager, isInverted: true)
        try exportSpan(through: eventManager)

        wait(for: [notSent], timeout: absenceTimeout)
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
        wait(for: [sent], timeout: 1)

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
        let notSent = expectSessionStart(from: eventManager, isInverted: true)
        publishReplayData(through: eventManager, after: defaultSession.currentSessionStart)

        wait(for: [notSent], timeout: absenceTimeout)
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

        let eventManager = try Manager(with: configuration, agent: agent)
        agent.eventManager = eventManager
        retainedAgents.append(agent)

        return (defaultSession, eventManager)
    }

    /// Returns an expectation fulfilled when the event manager sends a session start event.
    private func expectSessionStart(from eventManager: MockEventManager, isInverted: Bool = false) -> XCTestExpectation {
        let sessionStart = expectation(description: isInverted ? "session.start not sent" : "session.start sent")
        sessionStart.isInverted = isInverted

        eventManager.sentEventHandler = { event in
            if event.name == "session.start" {
                sessionStart.fulfill()
            }
        }

        return sessionStart
    }

    /// Ends one span on the event manager's tracer and waits until it is exported.
    private func exportSpan(through eventManager: DefaultEventManager) throws {
        let traceProcessor = eventManager.concreteTraceProcessor
        let tracer = traceProcessor.tracerProvider.get(instrumentationName: "test")

        tracer.spanBuilder(spanName: "span").startSpan().end()

        // A force flush from the main thread doesn't wait, so wait for the write to finish
        let exported = expectation(description: "span exported")
        traceProcessor.persistBufferedSpans(timeout: 5) { _ in
            exported.fulfill()
        }
        wait(for: [exported], timeout: 5)
    }

    /// Publishes Session Replay data recorded just after the session started.
    private func publishReplayData(through eventManager: DefaultEventManager, after sessionStart: Date) {
        // Replay data is matched to a session by time, so it starts just after the session did
        let startMs = Int((sessionStart.timeIntervalSince1970 + 0.01) * 1_000.0)
        let metadata = Metadata(startUnixMs: startMs, endUnixMs: startMs + 1)

        eventManager.publish(data: Data([0]), metadata: metadata) { _ in }
    }
}
