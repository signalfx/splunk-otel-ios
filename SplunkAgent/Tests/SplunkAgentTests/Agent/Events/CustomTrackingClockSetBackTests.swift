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
import Foundation
import SplunkCommon
import XCTest

@testable import SplunkAgent
@testable import SplunkCustomTracking
@testable import SplunkOpenTelemetry

/// After the device clock is set back, a custom event or error takes the session that is current when
/// it is published, and a Session Replay chunk keeps the lookup by its own timestamp.
///
/// The tests publish through the agent's event manager, as the custom tracking module does.
final class CustomTrackingClockSetBackTests: XCTestCase {

    // MARK: - Static constants

    /// A session that started two minutes before the test and was then replaced by the current one.
    private static let endedSessionId = "0123456789abcdef0123456789abcdef"


    // MARK: - Properties

    private var session: DefaultSession?
    private var agent: SplunkRum?
    private var eventManager: DefaultEventManager?


    // MARK: - Setup

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Building the event manager registers its tracer and logger providers globally.
        restoreOpenTelemetryGlobalsAtTeardown()

        // The stored sessions hold one earlier session; the session object closes it and starts the current one.
        let sessionsModel = SessionsModel(storage: UserDefaultsStorageTestBuilder.buildCleanStorage(named: UUID().uuidString))
        sessionsModel.sessions = [SessionItem(id: Self.endedSessionId, start: Date().addingTimeInterval(-120))]
        let session = DefaultSession(sessionsModel: sessionsModel)
        let configuration = try ConfigurationTestBuilder.buildDefault()
        let agent = try AgentTestBuilder.build(with: configuration, session: session)
        let eventManager = try DefaultEventManager(with: configuration, agent: agent)
        agent.eventManager = eventManager
        stopAtTeardown(agent)

        self.session = session
        self.agent = agent
        self.eventManager = eventManager
    }

    override func tearDown() {
        eventManager = nil
        agent = nil
        session = nil

        super.tearDown()
    }


    // MARK: - Tests

    /// The clock is set back into a session that has ended: the custom event takes the current session.
    func testEventInEndedSessionTakesCurrent() throws {
        let session = try XCTUnwrap(session)
        let currentSessionId = session.currentSessionId
        XCTAssertNotEqual(currentSessionId, Self.endedSessionId)

        // The clock is set back into the session that has ended.
        let trackedAt = Date().addingTimeInterval(-60)
        XCTAssertEqual(session.sessionId(for: trackedAt), Self.endedSessionId)

        let event = try publishCustomEvent(at: trackedAt)

        XCTAssertEqual(event.sessionId, currentSessionId)
    }

    /// The clock is set back to before any session existed: the custom event takes the current session.
    func testEventBeforeFirstSessionTakesCurrent() throws {
        let session = try XCTUnwrap(session)
        let currentSessionId = session.currentSessionId

        // The clock is set back to a time before any session existed.
        let trackedAt = Date().addingTimeInterval(-3_600)
        XCTAssertNil(session.sessionId(for: trackedAt))

        let event = try publishCustomEvent(at: trackedAt)

        XCTAssertEqual(event.sessionId, currentSessionId)
    }

    /// A Session Replay chunk keeps the lookup by its own timestamp, so with no session for it, it is not attributed.
    func testReplayChunkBeforeFirstSessionDropped() throws {
        let session = try XCTUnwrap(session)
        let eventManager = try XCTUnwrap(eventManager)

        // The same state as the custom event above: the timestamp lies before every session.
        let trackedAt = Date().addingTimeInterval(-3_600)
        XCTAssertNil(session.sessionId(for: trackedAt))

        let chunkMetadata = Metadata(
            startUnixMs: Int(trackedAt.timeIntervalSince1970 * 1_000.0),
            endUnixMs: Int(trackedAt.timeIntervalSince1970 * 1_000.0)
        )
        var completed: Bool?

        eventManager.publish(data: Data(), metadata: chunkMetadata) { completed = $0 }

        XCTAssertEqual(completed, false, "A Session Replay chunk with no session for its timestamp was attributed")
    }


    // MARK: - Helpers

    /// Publishes a custom event with the given timestamp and returns the event the agent built.
    private func publishCustomEvent(at timestamp: Date) throws -> any AgentEvent {
        let eventManager = try XCTUnwrap(eventManager)

        var metadata = CustomTrackingMetadata()
        metadata.timestamp = timestamp
        let data = CustomTrackingData(name: "purchase", component: "custom-event", attributes: [:])

        eventManager.publish(data: data, metadata: metadata) { _ in }

        let processor = try XCTUnwrap(eventManager.logEventProcessor as? OTLPLogToSpanEventProcessor)

        return try XCTUnwrap(processor.storedLastProcessedEvent)
    }
}
