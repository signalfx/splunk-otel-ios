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

import XCTest

@testable import SplunkAgent

final class API10SessionTests: XCTestCase {

    // MARK: - API Tests

    func testSession() throws {
        // Touch `Session` property
        let agent = try AgentTestBuilder.buildDefault()
        let session = agent.session
        XCTAssertNotNil(session)

        // State properties (READ)
        let currentSessionId = session.state.id
        XCTAssertNotNil(currentSessionId)

        let currentSamplingRate = session.state.samplingRate
        XCTAssertNotNil(currentSamplingRate)

        // Methods
        let sessionId = session.sessionId(for: Date())
        XCTAssertNotNil(sessionId)
    }

    func testMetadataIsValidBase64JSON() throws {
        let agent = try AgentTestBuilder.buildDefault()
        let metadataString = try XCTUnwrap(agent.session.metadata)

        // Must be valid Base64
        let jsonData = try XCTUnwrap(Data(base64Encoded: metadataString))

        // Must decode into a valid SessionMetadata
        let metadata = try JSONDecoder().decode(SessionMetadata.self, from: jsonData)

        XCTAssertEqual(metadata.sessionId, agent.session.state.id)
        XCTAssertGreaterThan(metadata.sessionStart, 0)
        XCTAssertGreaterThanOrEqual(metadata.sessionLastActivity, metadata.sessionStart)
    }

    func testMetadataAnonymousUserIdPresentWhenTrackingEnabled() throws {
        let agent = try AgentTestBuilder.buildDefault()
        agent.user.preferences.trackingMode = .anonymousTracking

        let metadataString = try XCTUnwrap(agent.session.metadata)
        let jsonData = try XCTUnwrap(Data(base64Encoded: metadataString))
        let metadata = try JSONDecoder().decode(SessionMetadata.self, from: jsonData)

        XCTAssertNotNil(metadata.anonymousUserId)
    }

    func testMetadataAnonymousUserIdAbsentWhenTrackingDisabled() throws {
        let agent = try AgentTestBuilder.buildDefault()
        agent.user.preferences.trackingMode = .noTracking

        let metadataString = try XCTUnwrap(agent.session.metadata)
        let jsonData = try XCTUnwrap(Data(base64Encoded: metadataString))
        let metadata = try JSONDecoder().decode(SessionMetadata.self, from: jsonData)

        XCTAssertNil(metadata.anonymousUserId)
    }

    func testMetadataSessionIdUpdatesAfterRotation() throws {
        let testName = "metadataSessionRotationTest"
        let defaultSession = try DefaultSessionTestBuilder.build(named: testName)
        let agent = try AgentTestBuilder.buildDefault()
        agent.currentSession = defaultSession
        defaultSession.owner = agent

        let metadataBefore = try XCTUnwrap(agent.session.metadata)
        let jsonBefore = try XCTUnwrap(Data(base64Encoded: metadataBefore))
        let before = try JSONDecoder().decode(SessionMetadata.self, from: jsonBefore)

        defaultSession.rotateSession()

        let metadataAfter = try XCTUnwrap(agent.session.metadata)
        let jsonAfter = try XCTUnwrap(Data(base64Encoded: metadataAfter))
        let after = try JSONDecoder().decode(SessionMetadata.self, from: jsonAfter)

        XCTAssertNotEqual(before.sessionId, after.sessionId)
    }
}
