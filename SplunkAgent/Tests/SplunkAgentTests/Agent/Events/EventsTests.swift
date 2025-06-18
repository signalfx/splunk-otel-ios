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

import CiscoSessionReplay
@testable import SplunkAgent
@testable import SplunkCommon
@testable import SplunkOpenTelemetry

import XCTest

final class EventsTests: XCTestCase {

    // MARK: - Private

    private var agent: SplunkRum?


    // MARK: - Setup

    override func setUpWithError() throws {
        // Setup Agent against a mock server
        let configuration = try ConfigurationTestBuilder.buildDefault()
        let mockAgent = try AgentTestBuilder.build(with: configuration)
        mockAgent.eventManager = try DefaultEventManager(with: configuration, agent: mockAgent)

        // Use mock agent
        agent = mockAgent
    }


    // MARK: - Testing Event manual events

    func testSessionReplayDataEvent() throws {
        let event = try SessionReplayTestBuilder.buildDataEvent()

        let requestExpectation = XCTestExpectation(description: "Send request")

        let eventManager = try XCTUnwrap(agent?.eventManager as? DefaultEventManager)
        let sessionReplayProcessor = try XCTUnwrap(eventManager.sessionReplayProcessor as? OTLPSessionReplayEventProcessor)

        sessionReplayProcessor.sendEvent(event, completion: { _ in
            requestExpectation.fulfill()
        })

        let processedEvent = try XCTUnwrap(sessionReplayProcessor.storedLastProcessedEvent)
        try checkEventAttributes(processedEvent)
        try checkEventProperties(processedEvent)

        XCTAssertEqual(processedEvent.name, "session_replay_data")

        wait(for: [requestExpectation], timeout: 5)
    }


    // MARK: - Testing immediate and background processing

    func testImmediateProcessing() throws {
        let event = try SessionReplayTestBuilder.buildDataEvent()
        let requestExpectation = XCTestExpectation(description: "Send request")

        let eventManager = try XCTUnwrap(agent?.eventManager as? DefaultEventManager)
        let sessionReplayProcessor = try XCTUnwrap(eventManager.sessionReplayProcessor as? OTLPSessionReplayEventProcessor)

        sessionReplayProcessor.sendEvent(event: event, immediateProcessing: true, completion: { success in
            XCTAssert(success)

            requestExpectation.fulfill()
        })

        XCTAssertNotNil(sessionReplayProcessor.storedLastProcessedEvent)
        XCTAssertNotNil(sessionReplayProcessor.storedLastSentEvent)
    }

    func testBackgroundProcessing() throws {
        let event = try SessionReplayTestBuilder.buildDataEvent()
        let requestExpectation = XCTestExpectation(description: "Send request")

        let eventManager = try XCTUnwrap(agent?.eventManager as? DefaultEventManager)
        let sessionReplayProcessor = try XCTUnwrap(eventManager.sessionReplayProcessor as? OTLPSessionReplayEventProcessor)

        sessionReplayProcessor.sendEvent(event, completion: { success in
            XCTAssert(success)

            requestExpectation.fulfill()
        })

        XCTAssertNotNil(sessionReplayProcessor.storedLastProcessedEvent)
        XCTAssertNil(sessionReplayProcessor.storedLastSentEvent)
    }


    // MARK: - Helpers

    func checkEventAttributes(_ event: SplunkCommon.AgentEvent) throws {
        let eventAttributes = try XCTUnwrap(event.attributes)

        // Metadata
        let metadataValue = eventAttributes["segmentMetadata"]
        let metadataData = try XCTUnwrap(metadataValue?.description.data(using: .utf8))
        let metadata = try JSONDecoder().decode(CiscoSessionReplay.Metadata.self, from: metadataData)
        XCTAssertNotNil(metadataValue)
        XCTAssertNotNil(metadata)

        // Script ID
        let scriptID = eventAttributes["splunk.scriptInstance"]
        XCTAssertNotNil(scriptID)

        // Experimental attributes for integration PoC
        let totalChunks = eventAttributes["rr-web.total-chunks"]
        XCTAssertEqual(totalChunks, .int(1))

        let chunk = eventAttributes["rr-web.chunk"]
        XCTAssertEqual(chunk, .int(1))

        let eventNumber = eventAttributes["rr-web.event"]
        XCTAssertEqual(eventNumber, .int(1))

        let offset = eventAttributes["rr-web.offset"]
        XCTAssertEqual(offset, .int(1))
    }

    func checkEventProperties(_ event: SplunkCommon.AgentEvent) throws {
        XCTAssertNotNil(event.domain)
        XCTAssertNotNil(event.name)
        XCTAssertNotNil(event.instrumentationScope)
        XCTAssertNotNil(event.component)

        XCTAssertNotNil(event.sessionId)
        XCTAssertNotNil(event.timestamp)
    }
}
