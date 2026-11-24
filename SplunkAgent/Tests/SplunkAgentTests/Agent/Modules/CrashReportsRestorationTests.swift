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
    import SplunkCommon
    import XCTest

    @testable import SplunkAgent
    @testable import SplunkCrashReports

    final class CrashReportsRestorationTests: XCTestCase {

        func testPendingCrashWaitsForRestorationWhileCurrentIdIsCached() throws {
            let fixture = try previousLaunch(named: "crashRestoration")
            let storage = BlockingHeldStartStorage(wrapping: fixture.storage, blocking: .read)
            let launch = try makeLaunch(named: "crashRestoration", storage: storage, pending: fixture.pending)
            stopAtTeardown(launch.agent)
            let readBlocked = observeBlockedRead(in: storage)
            defer {
                storage.unblock()
                launch.session.waitForHeldStartRestoration()
                launch.session.heldSessionStarts.waitForRequestedSaves()
            }

            launch.session.scheduleSessionStart()
            wait(for: [readBlocked], timeout: 10)
            launch.agent.startCrashReportProcessing(in: launch.reporter)
            drainCrashProcessing(for: launch.session)

            XCTAssertEqual(storage.finishedHeldStartReads, 0)
            XCTAssertEqual(launch.reporter.cachedSessionId, launch.session.currentSessionId)
            XCTAssertNotEqual(launch.session.currentSessionId, fixture.start.sessionId)
            XCTAssertEqual(launch.reporter.processingCount, 0)
            XCTAssertEqual(fixture.pending.sessionId, fixture.start.sessionId)
            XCTAssertTrue(launch.events.sentEvents.isEmpty)

            storage.unblock()
            launch.session.waitForHeldStartRestoration()
            drainCrashProcessing(for: launch.session)

            assertRecovered(fixture, in: launch)
        }

        func testInterruptedRecoveryLeavesPendingCrashForNextLaunch() throws {
            let fixture = try previousLaunch(named: "interruptedCrashRestoration")
            let storage = BlockingHeldStartStorage(wrapping: fixture.storage, blocking: .read)
            let readBlocked = observeBlockedRead(in: storage)
            let interruptedStore = HeldSessionStartStore(storage: storage)
            defer {
                storage.unblock()
                interruptedStore.waitForRequestedSaves()
            }

            weak var abandonedAgent: SplunkRum?
            weak var abandonedSession: DefaultSession?
            weak var abandonedReporter: RestorationCrashReportsSpy?
            do {
                let interrupted = try makeLaunch(
                    named: "interruptedCrashRestoration",
                    store: interruptedStore,
                    pending: fixture.pending
                )
                // Break the trace pipeline's reference to the agent so this launch can end.
                defer { interrupted.agent.eventManager = nil }

                abandonedAgent = interrupted.agent
                abandonedSession = interrupted.session
                abandonedReporter = interrupted.reporter

                interrupted.session.scheduleSessionStart()
                wait(for: [readBlocked], timeout: 10)
                interrupted.agent.startCrashReportProcessing(in: interrupted.reporter)
                drainCrashProcessing(for: interrupted.session)

                XCTAssertEqual(interrupted.reporter.processingCount, 0)
                XCTAssertEqual(fixture.pending.sessionId, fixture.start.sessionId)
                XCTAssertTrue(interrupted.events.sentEvents.isEmpty)
            }

            XCTAssertNil(abandonedAgent)
            XCTAssertNil(abandonedSession)
            XCTAssertNil(abandonedReporter)
            storage.unblock()
            interruptedStore.waitForRequestedSaves()
            XCTAssertEqual(storage.writtenHeldStartSaves, 0)
            XCTAssertEqual(try storage.storedHeldStarts(), [fixture.start])

            let next = try makeLaunch(named: "interruptedCrashRestoration", storage: fixture.storage, pending: fixture.pending)
            stopAtTeardown(next.agent)
            next.session.scheduleSessionStart()
            // Also exercise registration after the read and merge have already finished.
            next.session.waitForHeldStartRestoration()
            next.agent.startCrashReportProcessing(in: next.reporter)
            drainCrashProcessing(for: next.session)

            assertRecovered(fixture, in: next)
            next.session.heldSessionStarts.waitForRequestedSaves()
        }

        func testFailedRestorationStillProcessesCrashAndReleasesCurrentStart() throws {
            let fixture = try previousLaunch(named: "failedCrashRestoration")
            let failingStorage = FailingHeldStartReadStorage(wrapping: fixture.storage)
            let storage = BlockingHeldStartStorage(wrapping: failingStorage, blocking: .read)
            let launch = try makeLaunch(named: "failedCrashRestoration", storage: storage, pending: fixture.pending)
            stopAtTeardown(launch.agent)
            let readBlocked = observeBlockedRead(in: storage)
            defer {
                storage.unblock()
                launch.session.waitForHeldStartRestoration()
                launch.session.heldSessionStarts.waitForRequestedSaves()
            }

            launch.session.scheduleSessionStart()
            wait(for: [readBlocked], timeout: 10)
            // Disabling capture for this launch must still allow processing an older report.
            launch.reporter.isCrashReportingEnabled = false
            launch.agent.startCrashReportProcessing(in: launch.reporter)
            launch.session.trackAcceptedTelemetry(forSessionId: launch.session.currentSessionId)
            drainCrashProcessing(for: launch.session)
            XCTAssertEqual(launch.reporter.processingCount, 0)

            storage.unblock()
            launch.session.waitForHeldStartRestoration()
            drainCrashProcessing(for: launch.session)

            XCTAssertEqual(launch.reporter.processingCount, 1)
            XCTAssertNil(fixture.pending.sessionId)
            XCTAssertEqual(sessionStarts(in: launch).map(\.sessionId), [launch.session.currentSessionId])
        }

        // MARK: - Helpers

        private struct PreviousLaunch {
            let storage: KeyValueStorage
            let start: HeldSessionStartRecord
            let pending: RestorationCrashReportsSpy.PendingReport
        }

        private struct RecoveryLaunch {
            let agent: SplunkRum
            let session: DefaultSession
            let reporter: RestorationCrashReportsSpy
            let events: MockEventManager
        }

        private func previousLaunch(named name: String) throws -> PreviousLaunch {
            let storage = DefaultSessionTestBuilder.buildCleanHeldStartsStorage(named: name)
            let start = HeldSessionStartRecord(
                sessionId: "0123456789abcdef0123456789abcdef",
                start: Date(),
                previousSessionId: "fedcba9876543210fedcba9876543210",
                screenName: "PreviousScreen"
            )
            try storage.update([start], forKey: HeldSessionStartStore.storageKey)
            return PreviousLaunch(storage: storage, start: start, pending: .init(sessionId: start.sessionId))
        }

        private func makeLaunch(
            named name: String,
            storage: KeyValueStorage,
            pending: RestorationCrashReportsSpy.PendingReport
        ) throws -> RecoveryLaunch {
            try makeLaunch(named: name, store: HeldSessionStartStore(storage: storage), pending: pending)
        }

        private func makeLaunch(
            named name: String,
            store: HeldSessionStartStore,
            pending: RestorationCrashReportsSpy.PendingReport
        ) throws -> RecoveryLaunch {
            let globals = OpenTelemetryGlobals()
            defer { globals.restore() }

            let sessionsModel = SessionsModel(storage: UserDefaultsStorageTestBuilder.buildCleanStorage(named: name))
            let session = DefaultSession(sessionsModel: sessionsModel, heldSessionStarts: store)
            let configuration = try ConfigurationTestBuilder.buildDefault()
            let agent = try AgentTestBuilder.build(with: configuration, session: session)
            let events = try MockEventManager(with: configuration, agent: agent)
            agent.eventManager = events

            let reporter = RestorationCrashReportsSpy()
            reporter.configureCrashReporter()
            // Exercise the real ID cache without enabling native crash handlers.
            reporter.isCrashReportingEnabled = true
            reporter.sharedState = agent.sharedState
            reporter.session = session
            reporter.pendingReport = pending
            return RecoveryLaunch(agent: agent, session: session, reporter: reporter, events: events)
        }

        private func observeBlockedRead(in storage: BlockingHeldStartStorage) -> XCTestExpectation {
            let blocked = expectation(description: "held-start read is blocked")
            storage.didBlockRead = { blocked.fulfill() }
            return blocked
        }

        private func drainCrashProcessing(for session: DefaultSession) {
            // Wait for registration and any completed restoration to submit work to main, then
            // let main run that work before draining any resulting telemetry acceptance.
            _ = session.currentSessionId
            let drained = expectation(description: "main queue ran scheduled crash processing")
            DispatchQueue.main.async { drained.fulfill() }
            wait(for: [drained], timeout: 10)
            _ = session.currentSessionId
        }

        private func sessionStarts(in launch: RecoveryLaunch) -> [AgentEvent] {
            launch.events.sentEvents.filter { $0.name == "session.start" }
        }

        private func assertRecovered(
            _ fixture: PreviousLaunch,
            in launch: RecoveryLaunch,
            file: StaticString = #filePath,
            line: UInt = #line
        ) {
            XCTAssertEqual(launch.reporter.processingCount, 1, file: file, line: line)
            XCTAssertNil(fixture.pending.sessionId, file: file, line: line)

            let starts = sessionStarts(in: launch)
            XCTAssertEqual(starts.count, 1, file: file, line: line)
            XCTAssertEqual(starts.first?.sessionId, fixture.start.sessionId, file: file, line: line)
            XCTAssertEqual(starts.first?.timestamp, fixture.start.start, file: file, line: line)
            XCTAssertEqual(starts.first?.attributes?["session.previous_id"], fixture.start.previousSessionId.map { .string($0) }, file: file, line: line)
            XCTAssertEqual(starts.first?.attributes?["screen.name"], fixture.start.screenName.map { .string($0) }, file: file, line: line)
        }
    }

#endif
