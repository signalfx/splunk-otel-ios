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

@testable import SplunkAgent
@testable import SplunkOpenTelemetry
@testable import CiscoSessionReplay
@testable import SplunkSharedProtocols

import XCTest

final class EventsTests: XCTestCase {

    // MARK: - Private

    private var agent: SplunkRum?
    private var sampleVideoData: Data?


    // MARK: - Setup

    override func setUpWithError() throws {
        // Setup Agent against a mock server
        let configuration = try ConfigurationTestBuilder.buildDefault()
        let mockAgent = try AgentTestBuilder.build(with: configuration)
        mockAgent.eventManager = DefaultEventManager(with: configuration, agent: mockAgent)

        // Use mock agent
        agent = mockAgent

        try loadSampleVideo()
    }


    // MARK: - Testing Event manager events

    func testEventManagerSessionStartEvent() throws {
        let eventManager = try XCTUnwrap(agent?.eventManager as? DefaultEventManager)
        let logEventProcessor = try XCTUnwrap(eventManager.logEventProcessor as? OTLPLogEventProcessor)
        eventManager.eventsModel.clear()
        eventManager.sendSessionStartEvent()

        let processedEvent = try XCTUnwrap(logEventProcessor.storedLastProcessedEvent as? AgentEvent)
        XCTAssertEqual(processedEvent.name, "session_start")
    }

    func testEventManagerSessionPulseEvent() throws {
        let eventManager = try XCTUnwrap(agent?.eventManager)
        let logEventProcessor = try XCTUnwrap(eventManager.logEventProcessor as? OTLPLogEventProcessor)

        eventManager.sendSessionPulseEvent()

        let processedEvent = try XCTUnwrap(logEventProcessor.storedLastProcessedEvent as? AgentEvent)
        XCTAssertEqual(processedEvent.name, "session_pulse")
    }


    // MARK: - Testing Event manual events

    func testSessionStartEvent() throws {
        let sessionID = try XCTUnwrap(agent?.session.currentSessionId)
        let timestamp = Date()
        let userID = try XCTUnwrap(agent?.currentUser.userIdentifier)

        let event = SessionStartEvent(
            sessionID: sessionID,
            timestamp: timestamp,
            userID: userID
        )

        let requestExpectation = XCTestExpectation(description: "Send request")

        let eventManager = try XCTUnwrap(agent?.eventManager)
        let logEventProcessor = try XCTUnwrap(eventManager.logEventProcessor as? OTLPLogEventProcessor)

        eventManager.logEventProcessor.sendEvent(event, completion: { _ in
            // TODO: MRUM_AC-1111 - EventManager and Events tests
//            XCTAssert(success)

            requestExpectation.fulfill()
        })

        let processedEvent = try XCTUnwrap(logEventProcessor.storedLastProcessedEvent as? AgentEvent)
        try checkEventBaseAttributes(processedEvent)

        XCTAssertEqual(processedEvent.name, "session_start")

        wait(for: [requestExpectation], timeout: 5)
    }

    func testSessionPulseEvent() throws {
        let sessionID = try XCTUnwrap(agent?.session.currentSessionId)
        let timestamp = Date()

        let event = SessionPulseEvent(sessionID: sessionID, timestamp: timestamp)

        let requestExpectation = XCTestExpectation(description: "Send request")

        let eventManager = try XCTUnwrap(agent?.eventManager)
        let logEventProcessor = try XCTUnwrap(eventManager.logEventProcessor as? OTLPLogEventProcessor)

        logEventProcessor.sendEvent(event, completion: { _ in
            // TODO: MRUM_AC-1111 - EventManager and Events tests
//            XCTAssert(success)

            requestExpectation.fulfill()
        })

        let processedEvent = try XCTUnwrap(logEventProcessor.storedLastProcessedEvent as? AgentEvent)
        try checkEventBaseAttributes(processedEvent)

        XCTAssertEqual(processedEvent.name, "session_pulse")

        wait(for: [requestExpectation], timeout: 5)
    }

    func testSessionReplayDataEvent() throws {
        guard let sampleVideoData = sampleVideoData else {
            XCTFail("Missing sample video data")
            return
        }

        let sessionID = try XCTUnwrap(agent?.currentSession.currentSessionId)
        let recordID = UUID().uuidString
        let replaySessionID = UUID().uuidString
        let timestamp = Date()
        let endTimestamp = Date()

        // let recordMetadata = RecordMetadata(
        //    recordId: recordID,
        //    recordIndex: 0,
        //    timestamp: timestamp,
        //    timestampEnd: endTimestamp,
        //    replaySessionId: replaySessionID
        // )

        let datachunkMetadata = Metadata(startUnixMs: timestamp.timeIntervalSince1970 * 1000, endUnixMs: endTimestamp.timeIntervalSince1970 * 1000)

        let event = SessionReplayDataEvent(metadata: datachunkMetadata, data: sampleVideoData, sessionID: sessionID)

        let requestExpectation = XCTestExpectation(description: "Send request")

        let eventManager = try XCTUnwrap(agent?.eventManager)
        let logEventProcessor = try XCTUnwrap(eventManager.logEventProcessor as? OTLPLogEventProcessor)

        logEventProcessor.sendEvent(event, completion: { _ in
            // TODO: MRUM_AC-1111 - EventManager and Events tests
//            XCTAssert(success)

            requestExpectation.fulfill()
        })

        let processedEvent = try XCTUnwrap(logEventProcessor.storedLastProcessedEvent as? AgentEvent)
        try checkEventBaseAttributes(processedEvent)

        XCTAssertEqual(processedEvent.name, "session_replay_data")

        wait(for: [requestExpectation], timeout: 5)
    }


    // MARK: - Testing immediate and background processing

    func testImmediateProcessing() throws {
        let sessionID = try XCTUnwrap(agent?.session.currentSessionId)
        let timestamp = Date()

        let event = SessionPulseEvent(sessionID: sessionID, timestamp: timestamp)

        let requestExpectation = XCTestExpectation(description: "Send request")

        let eventManager = try XCTUnwrap(agent?.eventManager)
        let logEventProcessor = try XCTUnwrap(eventManager.logEventProcessor as? OTLPLogEventProcessor)

        logEventProcessor.sendEvent(event: event, immediateProcessing: true, completion: { success in
            XCTAssert(success)

            requestExpectation.fulfill()
        })

        let processedEvent = try XCTUnwrap(logEventProcessor.storedLastProcessedEvent as? AgentEvent)
        let sentEvent = try XCTUnwrap(logEventProcessor.storedLastSentEvent) as? AgentEvent

        XCTAssertTrue(processedEvent == sentEvent)
    }

    func testBackgroundProcessing() throws {
        let sessionID = try XCTUnwrap(agent?.session.currentSessionId)
        let timestamp = Date()

        let event = SessionPulseEvent(sessionID: sessionID, timestamp: timestamp)

        let requestExpectation = XCTestExpectation(description: "Send request")

        let eventManager = try XCTUnwrap(agent?.eventManager)
        let logEventProcessor = try XCTUnwrap(eventManager.logEventProcessor as? OTLPLogEventProcessor)

        logEventProcessor.sendEvent(event, completion: { success in
            XCTAssert(success)

            requestExpectation.fulfill()
        })

        let processedEvent = try XCTUnwrap(logEventProcessor.storedLastProcessedEvent as? AgentEvent)
        let sentEvent = logEventProcessor.storedLastSentEvent as? AgentEvent

        XCTAssertFalse(processedEvent == sentEvent)
    }

    func testDuplicateSessionStartEvents() throws {
        let agent = try XCTUnwrap(agent)
        let sessionID = try XCTUnwrap(agent.session.currentSessionId)
        let eventManager = try XCTUnwrap(agent.eventManager as? DefaultEventManager)

        let eventsModel = eventManager.eventsModel
        eventsModel.clear()

        XCTAssertTrue(eventManager.shouldSendSessionStart(sessionID))

        eventManager.sendSessionStartEvent()

        XCTAssertTrue(eventsModel.sendingSessionStartIDs.contains(sessionID))
        XCTAssertFalse(eventManager.shouldSendSessionStart(sessionID))

        let requestExpectation = XCTestExpectation(description: "Sent session start")

        simulateMainThreadWait(duration: 2.0)

        // Check if the session was marked as "sent"
        XCTAssertFalse(eventManager.shouldSendSessionStart(sessionID))

        eventManager.eventsModel.load()

        XCTAssertFalse(eventManager.shouldSendSessionStart(sessionID))
        XCTAssertTrue(eventsModel.sentSessionStartIDs.contains(sessionID))

        requestExpectation.fulfill()

        wait(for: [requestExpectation], timeout: 3.0)
    }


    // MARK: - Helpers

    func loadSampleVideo() throws {
        let bundle = Bundle(for: EventsTests.self)
        let fileUrl = bundle.url(forResource: "v", withExtension: "mp4")

        if let fileUrl = fileUrl {
            let data = try Data(contentsOf: fileUrl)

            sampleVideoData = data
        }
    }

    func checkEventBaseAttributes(_ event: SplunkSharedProtocols.Event) throws {
        XCTAssertNotNil(event.domain)
        XCTAssertNotNil(event.name)
        XCTAssertNotNil(event.instrumentationScope)

        XCTAssertNotNil(event.sessionID)
        XCTAssertNotNil(event.timestamp)
    }
}
