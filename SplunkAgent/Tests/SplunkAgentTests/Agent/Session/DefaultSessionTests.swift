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

final class DefaultSessionTests: XCTestCase {

    // MARK: - Basic logic

    func testBusinessLogic() throws {
        let testName = "defaultSessionTest"
        let storage = UserDefaultsStorageTestBuilder.buildCleanStorage(named: testName)
        let sessionModel = SessionsModel(storage: storage)
        let agent = try AgentTestBuilder.buildDefault()

        // After the object is created, there should be one open session
        let defaultSession = DefaultSession(sessionsModel: sessionModel)
        defaultSession.owner = agent
        XCTAssertEqual(sessionModel.sessions.count, 1)

        var resumedSessionItem = sessionModel.sessions[0]
        XCTAssertEqual(resumedSessionItem.id, defaultSession.currentSessionId)
        XCTAssertNil(resumedSessionItem.closed)


        /* Rotate Session */
        defaultSession.rotateSession()

        // After rotation we should have two sessions with the correct settings
        resumedSessionItem = sessionModel.sessions[0]
        let currentSessionItem = sessionModel.sessions[1]
        XCTAssertNotEqual(resumedSessionItem.id, currentSessionItem.id)


        /* End and Close Session */
        defaultSession.endSession()

        // Ended session should be closed
        let currentSession = defaultSession.currentSession
        XCTAssertTrue(currentSession.closed!)

        // State after ending should be saved in storage
        let keysPrefix = "\(PackageIdentifier.default).\(testName)."
        let matchedSessions = PersistentSessionsValidator.findPersistentMatches(
            with: sessionModel.sessions,
            keysPrefix: keysPrefix,
            storageKey: UserDefaultsStorageTestBuilder.defaultKey
        )
        XCTAssertEqual(sessionModel.sessions, matchedSessions)
    }

    func testSessionForLogic() throws {
        var configuration = try ConfigurationTestBuilder.buildDefault()
        configuration.maxSessionLength = 5

        // After the object is created, there should be one open session
        let testName = "sessionForLogicTest"
        let defaultSession = try DefaultSessionTestBuilder.build(named: testName)

        // We need to create a full agent as our session runner for this test
        let agent = try AgentTestBuilder.build(with: configuration, session: defaultSession)

        // Re-link session and agent each other
        defaultSession.owner = agent
        agent.currentSession = defaultSession

        let resumedSessionItem = defaultSession.currentSessionItem
        let resumedSessionId = resumedSessionItem.id

        var lastSessionItem = resumedSessionItem
        var lastSessionId = lastSessionItem.id

        // Retrieved session ID should be the resumed ID
        var retrievedSessionId = defaultSession.sessionId(for: Date())
        XCTAssertEqual(retrievedSessionId, resumedSessionId)

        simulateMainThreadWait(duration: 7)

        // After exceeding the maximum session length, we should get a new ID
        lastSessionItem = defaultSession.currentSessionItem
        lastSessionId = lastSessionItem.id

        retrievedSessionId = defaultSession.sessionId(for: Date())
        XCTAssertNotEqual(lastSessionId, resumedSessionId)
        XCTAssertEqual(retrievedSessionId, lastSessionId)

        // If we have no session in that period we should get `nil`
        let oneWeekInterval: TimeInterval = 7 * 24 * 60 * 60
        let weekAgo = Date() - oneWeekInterval

        retrievedSessionId = defaultSession.sessionId(for: weekAgo)
        XCTAssertNil(retrievedSessionId)

        let threshold: TimeInterval = 0.001
        var timestamp = Date()

        // Test session right before the first session's start
        timestamp = resumedSessionItem.start - threshold
        retrievedSessionId = defaultSession.sessionId(for: timestamp)
        XCTAssertNil(retrievedSessionId)

        // Test session right after the first session's start
        timestamp = resumedSessionItem.start + threshold
        retrievedSessionId = defaultSession.sessionId(for: timestamp)
        XCTAssertEqual(retrievedSessionId, resumedSessionId)

        // Test session right before the second session's start
        timestamp = lastSessionItem.start - threshold
        retrievedSessionId = defaultSession.sessionId(for: timestamp)
        XCTAssertEqual(retrievedSessionId, resumedSessionId)

        // Test session right after the second session's start
        timestamp = lastSessionItem.start + threshold
        retrievedSessionId = defaultSession.sessionId(for: timestamp)
        XCTAssertEqual(retrievedSessionId, lastSessionId)

        // Test session right before the second session's end
        timestamp = lastSessionItem.start + configuration.maxSessionLength - threshold
        retrievedSessionId = defaultSession.sessionId(for: timestamp)
        XCTAssertEqual(retrievedSessionId, lastSessionId)

        // Test session right after the second session's end
        let tolerance = defaultSession.sessionRefreshInterval + (defaultSession.refreshJob?.tolerance ?? 0.0)
        timestamp = lastSessionItem.start + configuration.maxSessionLength + tolerance + threshold
        retrievedSessionId = defaultSession.sessionId(for: timestamp)
        XCTAssertNil(retrievedSessionId)
    }


    // MARK: - Notifications

    func testEmittedNotification() throws {
        // After the object is created, there should be one open session
        let testName = "emittedNotificationTest"
        let defaultSession = try DefaultSessionTestBuilder.build(named: testName)
        let beforeResetId = defaultSession.currentSessionId


        // Watch for notification emitted *before* reset
        _ = expectation(
            forNotification: DefaultSession.sessionWillResetNotification,
            object: beforeResetId,
            handler: nil
        )

        // Watch for notification emitted *after* reset
        _ = expectation(
            forNotification: DefaultSession.sessionDidResetNotification,
            object: nil,
            handler: nil
        )

        // Rotate current session
        defaultSession.rotateSession()

        // We need to wait for notification delivery
        waitForExpectations(timeout: 3, handler: nil)
    }
}


// swiftformat:disable indent
#if os(iOS) || os(tvOS) || os(visionOS)

extension DefaultSessionTests {

    // MARK: - Application lifecycle

    func testEnterBackground() throws {
        let configuration = try ConfigurationTestBuilder.buildDefault()

        // After the object is created, there should be one open session
        let testName = "enterBackgroundTest"
        let defaultSession = try DefaultSessionTestBuilder.build(named: testName)
        defaultSession.testSessionTimeout = 10

        // We need to create a full agent as our session runner for this test
        let agent = try AgentTestBuilder.build(with: configuration, session: defaultSession)

        /* Going into the background for *allowed* time */
        let resumedSessionId = defaultSession.currentSessionId
        try simulateBackgroundStay(for: defaultSession, duration: 3)
        simulateMainThreadWait(duration: 2)

        // The current session should be the same
        var lastSessionId = defaultSession.currentSessionId
        XCTAssertEqual(lastSessionId, resumedSessionId)

        // Simulate some inactivity
        simulateMainThreadWait(duration: 8)

        // After a previous stay in the background and some inactivity time,
        // there should be the same session ID.
        lastSessionId = defaultSession.currentSessionId
        XCTAssertEqual(lastSessionId, resumedSessionId)


        /* Going into the background for *too long* time */
        try simulateBackgroundStay(for: defaultSession, duration: 12)
        simulateMainThreadWait(duration: 2)

        // The current session should *not* be the same
        XCTAssertNotEqual(lastSessionId, defaultSession.currentSessionId)
        XCTAssertNotNil(agent)
    }

    func testTerminateApplication() throws {
        // After the object is created, there should be one open session
        let testName = "terminateApplicationTest"
        let defaultSession = try DefaultSessionTestBuilder.build(named: testName)


        // Watch for notification emitted from simulated UIKit
        _ = expectation(
            forNotification: UIApplication.willTerminateNotification,
            object: nil,
            handler: nil
        )

        // Send simulated termination
        NotificationCenter.default.post(
            name: UIApplication.willTerminateNotification,
            object: nil
        )

        // We need to wait for notification delivery
        waitForExpectations(timeout: 5, handler: nil)

        // Current session should be closed
        let currentSession = defaultSession.currentSession
        XCTAssertTrue(currentSession.closed!)
    }
}

#endif
// swiftformat:enable indent
