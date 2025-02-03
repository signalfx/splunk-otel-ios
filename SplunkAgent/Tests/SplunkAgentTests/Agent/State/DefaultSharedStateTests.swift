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
import XCTest

final class DefaultSharedStateTests: XCTestCase {

    // MARK: - Tests

    func testProperties() throws {
        // Touch `SessionId` property
        let agent = try AgentTestBuilder.buildDefault()
        let sharedState = DefaultSharedState(for: agent)

        // Properties (READ)
        let sessionId = sharedState.sessionId
        XCTAssertNotNil(sessionId)

        // The returned value should be the current session ID
        let currentSessionId = agent.currentSession.currentSessionId
        XCTAssertEqual(sessionId, currentSessionId)

        // Check if SessionItem holds correct information
        let currentSessionItem = agent.currentSession.currentSessionItem
        XCTAssertEqual(sessionId, currentSessionItem.id)
        XCTAssertNotNil(currentSessionItem.start)
    }

    func testAppStateRetrieval() throws {
        let agent = try AgentTestBuilder.buildDefault()
        let sharedState = DefaultSharedState(for: agent)

        sendSimulatedNotification(UIApplication.didBecomeActiveNotification)

        let activeAppStateExpectation = agent.sharedState.applicationState(for: Date())
        XCTAssertNotNil(activeAppStateExpectation)
        XCTAssertEqual(activeAppStateExpectation, "active")

        sendSimulatedNotification(UIApplication.willResignActiveNotification)

        let inactiveAppStateExpectation = agent.sharedState.applicationState(for: Date())
        XCTAssertNotNil(inactiveAppStateExpectation)
        XCTAssertEqual(inactiveAppStateExpectation, "inactive")
    }
}
