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

#if canImport(SplunkCrashReports)

    import Foundation
    import XCTest

    @testable import SplunkAgent
    @testable import SplunkCommon
    @testable import SplunkCrashReports

    final class CrashReportsSessionChangeTests: XCTestCase {

        // MARK: - Private

        /// Timeout for something that must happen.
        ///
        /// The wait ends as soon as it happens, so a long limit costs nothing when the code works
        /// and tolerates a stalled test machine.
        private let arrivalTimeout: TimeInterval = 10


        // MARK: - Tests

        func testAgentCachesSessionIdNowAndAfterRotation() throws {
            let session = try DefaultSessionTestBuilder.build(named: "crashSessionIdTest")
            let agent = try AgentTestBuilder.build(with: ConfigurationTestBuilder.buildDefault(), session: session)
            stopAtTeardown(agent)
            let crashReports = makeCrashReports(sharedState: agent.sharedState)

            // As at installation.
            agent.keepCrashReportSessionIdCurrent(in: crashReports)
            let observer = try XCTUnwrap(agent.crashReportsSessionObserver)
            addTeardownBlock {
                NotificationCenter.default.removeObserver(observer)
            }

            let firstId = session.currentSessionId
            XCTAssertEqual(
                cachedSessionId(in: crashReports),
                firstId,
                "The session ID was not stored before the installation step returned."
            )

            // The agent rotates sessions on the main thread.
            session.rotateSession(previousSessionId: firstId)
            let secondId = session.currentSessionId
            XCTAssertNotEqual(secondId, firstId)
            XCTAssertEqual(
                cachedSessionId(in: crashReports),
                secondId,
                "The new session ID was not stored before the rotation on the main thread returned."
            )

            withExtendedLifetime(agent) {}
        }

        func testSessionChangePostedOffTheMainThreadReachesTheCrashReporter() {
            let sharedState = TestSharedState()
            sharedState.sessionId = "0123456789abcdef0123456789abcdef"
            let crashReports = makeCrashReports(sharedState: sharedState)

            let observer = SplunkRum.observeSessionChanges(for: crashReports)
            addTeardownBlock {
                NotificationCenter.default.removeObserver(observer)
            }

            let newId = "fedcba9876543210fedcba9876543210"
            sharedState.sessionId = newId

            let posted = expectation(description: "Posted on a background queue")
            DispatchQueue.global(qos: .utility)
                .async {
                    NotificationCenter.default.post(name: DefaultSession.sessionDidResetNotification, object: newId)
                    posted.fulfill()
                }
            wait(for: [posted], timeout: arrivalTimeout)

            let cached = expectation(
                for: NSPredicate { _, _ in
                    self.cachedSessionId(in: crashReports) == newId
                },
                evaluatedWith: crashReports
            )
            wait(for: [cached], timeout: arrivalTimeout)

            withExtendedLifetime(sharedState) {}
        }


        // MARK: - Helpers

        /// A configured crash reporter that stores custom data, reading the session ID from `sharedState`.
        ///
        /// `isCrashReportingEnabled` stands in for `initializeCrashReporter()`, which would enable a
        /// real crash handler. The caller keeps the owner of `sharedState` alive, because the reporter
        /// holds it unowned.
        private func makeCrashReports(sharedState: AgentSharedState) -> CrashReports {
            let crashReports = CrashReports()
            crashReports.configureCrashReporter()
            crashReports.isCrashReportingEnabled = true
            crashReports.sharedState = sharedState

            return crashReports
        }

        private func cachedSessionId(in crashReports: CrashReports) -> String? {
            guard let data = crashReports.crashReporter?.customData else {
                return nil
            }

            let customData =
                try? NSKeyedUnarchiver.unarchivedObject(
                    ofClasses: [NSDictionary.self, NSString.self],
                    from: data
                ) as? [String: String]

            return customData?[CrashReportCustomDataKeys.sessionId.rawValue]
        }
    }


    // MARK: - Test Support

    /// A shared state whose session ID the test sets.
    ///
    /// `@unchecked Sendable`: the test writes `sessionId` before it posts the session change, and the
    /// crash reporter reads it afterwards on the main thread.
    private final class TestSharedState: AgentSharedState, @unchecked Sendable {
        var sessionId = ""
        let agentVersion = "test"

        func applicationState(for _: Date) -> String? {
            nil
        }
    }

#endif
