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

import Foundation
import SplunkCommon
import XCTest

#if os(iOS) || os(tvOS) || os(visionOS)

    import UIKit

    @testable import SplunkSlowFrameDetector

    // MARK: - SlowFrameLogicWatchdogTests

    /// Wall-clock tests for the `SlowFrameLogic` actor's background watchdog, which detects a true
    /// main-thread hang (no `CADisplayLink` callback at all).
    ///
    /// Deterministic, `handleFrame`-only tests live in `SlowFrameLogicTests`.
    @MainActor
    final class SlowFrameLogicWatchdogTests: XCTestCase {

        // MARK: - Test Properties

        private var logic: SlowFrameLogic?
        private var mockDestination: MockDestination?

        private let cadence60Hz: TimeInterval = 1.0 / 60.0


        // MARK: - Test Lifecycle

        override func setUp() async throws {
            try await super.setUp()
            let destination = MockDestination()
            mockDestination = destination
            logic = SlowFrameLogic(destination: destination)

            try await logic?.start()
        }

        override func tearDown() async throws {
            await logic?.stop()
            logic = nil
            mockDestination = nil

            try await super.tearDown()
        }


        // MARK: - Watchdog Tests

        /// Verifies that a frozen frame is detected when the ticker stops firing entirely (a true main-thread hang),
        /// relying on the background watchdog.
        ///
        /// Depends on wall-clock timing, since it exercises the watchdog's real-hang detection path.
        func testFrozenFrameIsDetectedWhenFramesStop() async throws {
            let logic = try XCTUnwrap(logic)
            let mockDestination = try XCTUnwrap(mockDestination)

            await logic.handleFrame(timestamp: 0.0, targetTimestamp: cadence60Hz)

            // With no further frames, the watchdog must observe the stale heartbeat and count one
            // frozen episode. The helper polls with proper task cleanup on both success and failure.
            try await waitUntilTotalFrozenEpisodes(atLeast: 1, logic: logic, destination: mockDestination)

            await logic.flushBuffers()

            let counts = mockDestination.reportedCounts
            XCTAssertEqual(counts["frozenRenders"], 1, "Expected exactly one frozen render to be reported.")
        }

        /// Verifies that a long freeze detected by the watchdog still correctly reports exactly one
        /// event, regardless of how long the freeze continues.
        func testLongFreezeReportsOneEvent() async throws {
            let logic = try XCTUnwrap(logic)
            let mockDestination = try XCTUnwrap(mockDestination)
            let hangTime = SlowFrameDetector.frozenFrameThreshold * 3.5

            await logic.handleFrame(timestamp: 0.0, targetTimestamp: cadence60Hz)

            try await Task.sleep(nanoseconds: UInt64(hangTime * 1_000_000_000))

            await logic.flushBuffers()

            let counts = mockDestination.reportedCounts
            XCTAssertEqual(counts["frozenRenders"], 1, "One continuous freeze must be reported exactly once.")
        }

        /// Verifies that a recovery frame after a watchdog-detected freeze clears `inFreezeEpisode`, so a
        /// second, distinct freeze is independently detected and counted by the watchdog.
        ///
        /// Depends on wall-clock timing, like the other watchdog tests above, to exercise the real
        /// `runWatchdog` loop rather than the deterministic `handleFrame`-only stall path.
        func testWatchdogCountsSecondDistinctFreezeAfterRecovery() async throws {
            let logic = try XCTUnwrap(logic)
            let mockDestination = try XCTUnwrap(mockDestination)

            await logic.handleFrame(timestamp: 0.0, targetTimestamp: cadence60Hz)

            // First freeze, detected by the watchdog.
            try await waitUntilTotalFrozenEpisodes(atLeast: 1, logic: logic, destination: mockDestination)

            // Recovery frame: ends the open freeze episode without itself being counted, and re-arms
            // the heartbeat and cadence baseline for a new episode.
            await logic.handleFrame(timestamp: 100.0, targetTimestamp: 100.0 + cadence60Hz)

            // Second, distinct freeze: the watchdog must detect and count it independently of the first.
            try await waitUntilTotalFrozenEpisodes(atLeast: 2, logic: logic, destination: mockDestination)

            await logic.flushBuffers()

            let counts = mockDestination.reportedCounts
            XCTAssertEqual(
                counts["frozenRenders"],
                2,
                "Two distinct freeze episodes, separated by a recovery frame, must each be counted."
            )
        }

        /// Verifies that frozen frames are not counted while the app is inactive.
        func testFrozenFramesNotCountedWhenAppResignsActive() async throws {
            let logic = try XCTUnwrap(logic)
            let mockDestination = try XCTUnwrap(mockDestination)

            // Establish a heartbeat so the watchdog would normally have something to check.
            await logic.handleFrame(timestamp: 0.0, targetTimestamp: cadence60Hz)

            // Simulate app moving to background; this resets the heartbeat.
            await logic.appWillResignActive()

            // Wait longer than the frozen frame threshold to ensure the watchdog runs.
            try await Task.sleep(nanoseconds: UInt64((SlowFrameDetector.frozenFrameThreshold + 0.1) * 1_000_000_000))

            // No frozen frames should have been recorded while inactive.
            let frozenCount = await logic.testFrozenFrameCount
            XCTAssertEqual(frozenCount, 0)

            await logic.flushBuffers()
            let counts = mockDestination.reportedCounts
            XCTAssertNil(counts["frozenRenders"])
        }


        // MARK: - Helper Methods

        /// Polls the total number of frozen episodes observed so far until it reaches `count`, for
        /// watchdog tests that must wait on the real background timer rather than a deterministic
        /// `handleFrame` call.
        ///
        /// The total is the accumulated destination count plus the actor's currently buffered count.
        /// The actor's one-second flush loop periodically drains the buffered count into the
        /// destination, so the buffered count alone oscillates and never reflects the running total.
        /// Reading flushed before buffered can transiently undercount if a flush lands between the two
        /// reads, but never overcounts, and the next poll observes the correct total; so waiting on the
        /// sum reaching `count` is safe.
        private func waitUntilTotalFrozenEpisodes(
            atLeast count: Int,
            logic: SlowFrameLogic,
            destination: MockDestination
        ) async throws {
            let expectation = XCTestExpectation(description: "total frozen episodes reached \(count)")

            let pollTask = Task {
                while !Task.isCancelled {
                    // Read the flushed count first, then the buffered count. The one-second flush loop
                    // moves an event from the buffer to the destination between these two reads; reading
                    // flushed first means a just-flushed event is missed here but caught on the next
                    // poll. Reading buffered first would let the same event appear in both reads and
                    // double-count.
                    let flushed = destination.reportedCounts["frozenRenders"] ?? 0
                    let buffered = await logic.testFrozenFrameCount
                    if buffered + flushed >= count {
                        expectation.fulfill()
                        break
                    }
                    try? await Task.sleep(nanoseconds: 10_000_000) // Check every 10ms
                }
            }
            defer { pollTask.cancel() }

            // Generous timeout: the watchdog's 700ms phase is independent of the heartbeat, so a single
            // detection can take well over one threshold interval under CI scheduling jitter.
            await fulfillment(of: [expectation], timeout: 4.0)
        }
    }
#endif // os(iOS) || os(tvOS) || os(visionOS)
