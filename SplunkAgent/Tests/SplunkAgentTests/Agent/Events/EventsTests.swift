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
        let event = try SessionReplayTestBuilder.buildDataEvent()
        let requestExpectation = XCTestExpectation(description: "Send request")

        let eventManager = try XCTUnwrap(agent?.eventManager)
        let logEventProcessor = try XCTUnwrap(eventManager.logEventProcessor as? OTLPLogEventProcessor)

        logEventProcessor.sendEvent(event: event, immediateProcessing: true, completion: { success in
            XCTAssert(success)

            requestExpectation.fulfill()
        })

        XCTAssertNotNil(logEventProcessor.storedLastProcessedEvent)
        XCTAssertNotNil(logEventProcessor.storedLastSentEvent)
    }

    func testBackgroundProcessing() throws {
        let event = try SessionReplayTestBuilder.buildDataEvent()
        let requestExpectation = XCTestExpectation(description: "Send request")

        let eventManager = try XCTUnwrap(agent?.eventManager)
        let logEventProcessor = try XCTUnwrap(eventManager.logEventProcessor as? OTLPLogEventProcessor)

        logEventProcessor.sendEvent(event, completion: { success in
            XCTAssert(success)

            requestExpectation.fulfill()
        })

        XCTAssertNotNil(logEventProcessor.storedLastProcessedEvent)
        XCTAssertNil(logEventProcessor.storedLastSentEvent)
    }


    // MARK: - Helpers

    func checkEventBaseAttributes(_ event: SplunkCommon.AgentEvent) throws {
        XCTAssertNotNil(event.domain)
        XCTAssertNotNil(event.name)
        XCTAssertNotNil(event.instrumentationScope)
        XCTAssertNotNil(event.component)

        XCTAssertNotNil(event.sessionID)
        XCTAssertNotNil(event.timestamp)
    }
}
