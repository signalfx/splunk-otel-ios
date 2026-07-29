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

    // MARK: - SlowFrameLogicTests

    /// Deterministic tests for the `SlowFrameLogic` actor's detection algorithm, keyed to the
    /// DEMRUM-6028 test plan scenarios.
    ///
    /// Detector/ticker integration tests live in `SplunkSlowFrameDetectorTests`.
    @MainActor
    final class SlowFrameLogicTests: XCTestCase {

        // MARK: - Test Properties

        private var logic: SlowFrameLogic?
        private var mockDestination: MockDestination?

        private let cadence60Hz: TimeInterval = 1.0 / 60.0
        private let cadence120Hz: TimeInterval = 1.0 / 120.0


        // MARK: - Test Lifecycle

        override func setUp() async throws {
            try await super.setUp()
            let destination = MockDestination()
            mockDestination = destination
            // Intentionally do not call `start()`. These tests drive `handleFrame` and `flushBuffers`
            // directly, so the background watchdog and flush timers are omitted to keep them fully
            // deterministic. Watchdog behavior is covered by `SlowFrameLogicWatchdogTests`.
            logic = SlowFrameLogic(destination: destination)
        }

        override func tearDown() async throws {
            await logic?.stop()
            logic = nil
            mockDestination = nil

            try await super.tearDown()
        }


        // MARK: - Lifecycle Notification Tests (Scenario 4)

        /// Verifies that the logic state is reset when the app becomes active, and the first
        /// callback after foregrounding does not produce a render event.
        func testStateIsResetOnAppDidBecomeActive() async throws {
            let logic = try XCTUnwrap(logic)
            let mockDestination = try XCTUnwrap(mockDestination)

            await logic.handleFrame(timestamp: 0.0, targetTimestamp: cadence60Hz)
            // This would normally be a slow frame relative to the previous target.
            await logic.handleFrame(timestamp: 0.1, targetTimestamp: 0.1 + cadence60Hz)

            await logic.appDidBecomeActive(at: 10.0)

            // This frame should now be treated as the first frame, not triggering a report.
            await logic.handleFrame(timestamp: 10.0, targetTimestamp: 10.0 + cadence60Hz)

            await logic.flushBuffers()

            let counts = mockDestination.reportedCounts
            XCTAssertTrue(counts.isEmpty, "No reports should be sent after app becomes active.")
        }

        /// Verifies that pending buffers are flushed when the app resigns active.
        func testBuffersAreFlushedOnAppWillResignActive() async throws {
            let logic = try XCTUnwrap(logic)
            let mockDestination = try XCTUnwrap(mockDestination)

            await logic.handleFrame(timestamp: 0.0, targetTimestamp: cadence60Hz)
            await logic.handleFrame(timestamp: 0.1, targetTimestamp: 0.1 + cadence60Hz)

            // This will trigger flushBuffers internally
            await logic.appWillResignActive()

            let counts = mockDestination.reportedCounts
            XCTAssertEqual(counts["slowRenders"], 1)
        }

        /// Verifies that no render event is produced for background time, a frame still in flight when
        /// the app resigns active, or the first callback after foregrounding.
        func testNoEventsAcrossBackgroundForegroundTransition() async throws {
            let logic = try XCTUnwrap(logic)
            let mockDestination = try XCTUnwrap(mockDestination)
            await logic.handleFrame(timestamp: 0.0, targetTimestamp: cadence60Hz)
            await logic.appWillResignActive()
            // Simulates a frame already in flight when the lifecycle notification landed; must not
            // re-arm the heartbeat or seed a stale baseline.
            await logic.handleFrame(timestamp: 50.0, targetTimestamp: 50.0 + cadence60Hz)
            let heartbeat = await logic.testLastHeartbeatTimestamp
            XCTAssertEqual(heartbeat, 0, "A frame delivered while inactive must not re-arm the heartbeat.")
            await logic.appDidBecomeActive(at: 100.0)
            // First callback after foregrounding establishes a new baseline, no event.
            await logic.handleFrame(timestamp: 100.0, targetTimestamp: 100.0 + cadence60Hz)
            await logic.flushBuffers()
            let counts = mockDestination.reportedCounts
            XCTAssertTrue(counts.isEmpty)
        }

        /// Verifies that a pre-background frame still buffered in the ticker stream, but not delivered to
        /// the actor until after foregrounding, is discarded rather than seeding the baseline.
        ///
        /// The `isActive` guard alone cannot reject this frame: it is processed while active, so only its
        /// timestamp (produced before the activation instant) distinguishes it. Without the cutoff, the
        /// stale timestamp would seed the baseline and the next real frame's gap would span the whole
        /// background interval, emitting a spurious frozen render.
        func testStaleBufferedTickAfterForegroundIsDiscarded() async throws {
            let logic = try XCTUnwrap(logic)
            let mockDestination = try XCTUnwrap(mockDestination)

            await logic.handleFrame(timestamp: 0.0, targetTimestamp: cadence60Hz)
            await logic.appWillResignActive()
            await logic.appDidBecomeActive(at: 100.0)

            // Stale pre-background tick, delivered late; must be discarded, not seed the baseline.
            await logic.handleFrame(timestamp: 1.0, targetTimestamp: 1.0 + cadence60Hz)
            // First genuine foreground frame at/after the cutoff establishes the baseline, no event.
            await logic.handleFrame(timestamp: 100.0, targetTimestamp: 100.0 + cadence60Hz)
            // A subsequent steady frame produces no event.
            await logic.handleFrame(
                timestamp: 100.0 + cadence60Hz,
                targetTimestamp: 100.0 + 2 * cadence60Hz
            )

            await logic.flushBuffers()

            let counts = mockDestination.reportedCounts
            XCTAssertTrue(counts.isEmpty, "A stale pre-background tick must not produce any render event.")
        }


        // MARK: - Frame Detection Tests

        /// Verifies that the very first frame processed does not trigger a report.
        func testFirstFrameDoesNotTriggerReport() async throws {
            let logic = try XCTUnwrap(logic)
            let mockDestination = try XCTUnwrap(mockDestination)

            await logic.handleFrame(timestamp: 0.0, targetTimestamp: cadence60Hz)
            await logic.flushBuffers()

            let counts = mockDestination.reportedCounts
            XCTAssertTrue(counts.isEmpty)
        }

        // MARK: Scenario 1 - normal cadence produces no slow renders

        /// Verifies that steady 60 Hz cadence produces no slow renders.
        func testNoSlowRenderAtSteady60Hz() async throws {
            let logic = try XCTUnwrap(logic)
            let mockDestination = try XCTUnwrap(mockDestination)

            await logic.handleFrame(timestamp: 0.0, targetTimestamp: cadence60Hz)
            await logic.handleFrame(timestamp: cadence60Hz, targetTimestamp: 2 * cadence60Hz)
            await logic.handleFrame(timestamp: 2 * cadence60Hz, targetTimestamp: 3 * cadence60Hz)

            await logic.flushBuffers()

            let counts = mockDestination.reportedCounts
            XCTAssertTrue(counts.isEmpty)
        }

        /// Verifies that steady 120 Hz cadence produces no slow renders.
        func testNoSlowRenderAtSteady120Hz() async throws {
            let logic = try XCTUnwrap(logic)
            let mockDestination = try XCTUnwrap(mockDestination)

            await logic.handleFrame(timestamp: 0.0, targetTimestamp: cadence120Hz)
            await logic.handleFrame(timestamp: cadence120Hz, targetTimestamp: 2 * cadence120Hz)
            await logic.handleFrame(timestamp: 2 * cadence120Hz, targetTimestamp: 3 * cadence120Hz)

            await logic.flushBuffers()

            let counts = mockDestination.reportedCounts
            XCTAssertTrue(counts.isEmpty)
        }

        /// Verifies that a dynamic cadence change (120 Hz -> 60 Hz) produces no slow renders,
        /// since the frame arrives on time for its own (new) cadence.
        func testNoSlowRenderOnDynamicCadenceChange() async throws {
            let logic = try XCTUnwrap(logic)
            let mockDestination = try XCTUnwrap(mockDestination)

            // Steady 120 Hz.
            await logic.handleFrame(timestamp: 0.0, targetTimestamp: cadence120Hz)
            await logic.handleFrame(timestamp: cadence120Hz, targetTimestamp: 2 * cadence120Hz)

            // Cadence drops to 60 Hz starting with this frame.
            let switchTimestamp = 2 * cadence120Hz
            await logic.handleFrame(timestamp: switchTimestamp, targetTimestamp: switchTimestamp + cadence60Hz)
            await logic.handleFrame(
                timestamp: switchTimestamp + cadence60Hz,
                targetTimestamp: switchTimestamp + 2 * cadence60Hz
            )

            await logic.flushBuffers()

            let counts = mockDestination.reportedCounts
            XCTAssertTrue(counts.isEmpty)
        }

        // MARK: Scenario 2 - one missed presentation deadline produces one slow render

        /// Verifies that a single missed presentation deadline at 60 Hz is detected as one slow render.
        func testOneMissedDeadlineAt60HzIsDetected() async throws {
            let logic = try XCTUnwrap(logic)
            let mockDestination = try XCTUnwrap(mockDestination)

            await logic.handleFrame(timestamp: 0.0, targetTimestamp: cadence60Hz)
            // Arrives after missing exactly one presentation opportunity.
            await logic.handleFrame(timestamp: 2 * cadence60Hz, targetTimestamp: 3 * cadence60Hz)

            await logic.flushBuffers()

            let counts = mockDestination.reportedCounts
            XCTAssertEqual(counts["slowRenders"], 1)
            XCTAssertNil(counts["frozenRenders"])
        }

        /// Verifies that a single missed presentation deadline at 120 Hz is detected as one slow render.
        func testOneMissedDeadlineAt120HzIsDetected() async throws {
            let logic = try XCTUnwrap(logic)
            let mockDestination = try XCTUnwrap(mockDestination)

            await logic.handleFrame(timestamp: 0.0, targetTimestamp: cadence120Hz)
            await logic.handleFrame(timestamp: 2 * cadence120Hz, targetTimestamp: 3 * cadence120Hz)

            await logic.flushBuffers()

            let counts = mockDestination.reportedCounts
            XCTAssertEqual(counts["slowRenders"], 1)
            XCTAssertNil(counts["frozenRenders"])
        }

        /// Verifies that a frame arriving at (or just past) the detection boundary is correctly classified as slow.
        ///
        /// A tiny epsilon past the exact boundary avoids floating-point rounding flakiness in the
        /// `>=` comparison while still exercising the boundary condition.
        func testSlowFrameAtBoundaryIsDetected() async throws {
            let logic = try XCTUnwrap(logic)
            let mockDestination = try XCTUnwrap(mockDestination)

            let epsilon: TimeInterval = 1e-9
            let latenessAtBoundary = cadence60Hz - SlowFrameDetector.cadenceJitterMargin + epsilon

            await logic.handleFrame(timestamp: 0.0, targetTimestamp: cadence60Hz)
            await logic.handleFrame(
                timestamp: cadence60Hz + latenessAtBoundary,
                targetTimestamp: cadence60Hz + latenessAtBoundary + cadence60Hz
            )

            await logic.flushBuffers()

            let counts = mockDestination.reportedCounts
            XCTAssertEqual(counts["slowRenders"], 1)
        }

        // MARK: Scenario 3 - a stall longer than 700ms produces one frozen render, no slow render

        /// Verifies that a stall longer than the frozen threshold, observed directly via `handleFrame`,
        /// is reported as exactly one frozen render and never as a slow render.
        ///
        /// This is fully deterministic and does not depend on the background watchdog timer.
        func testStallOverThresholdIsDetectedAsFrozenNotSlow() async throws {
            let logic = try XCTUnwrap(logic)
            let mockDestination = try XCTUnwrap(mockDestination)

            await logic.handleFrame(timestamp: 0.0, targetTimestamp: cadence60Hz)

            let stallDuration = SlowFrameDetector.frozenFrameThreshold + 0.05
            await logic.handleFrame(
                timestamp: cadence60Hz + stallDuration,
                targetTimestamp: cadence60Hz + stallDuration + cadence60Hz
            )

            await logic.flushBuffers()

            let counts = mockDestination.reportedCounts
            XCTAssertEqual(counts["frozenRenders"], 1)
            XCTAssertNil(counts["slowRenders"])
        }

        /// Verifies that a multi-second stall, observed directly via `handleFrame`, still produces
        /// exactly one frozen render (one continuous freeze episode), not multiple.
        ///
        /// Same `handleFrame` branch as the test above; kept separate since the test plan names it explicitly.
        func testMultiSecondStallIsDetectedAsOneFrozenEvent() async throws {
            let logic = try XCTUnwrap(logic)
            let mockDestination = try XCTUnwrap(mockDestination)

            await logic.handleFrame(timestamp: 0.0, targetTimestamp: cadence60Hz)

            let stallDuration: TimeInterval = 3.5
            await logic.handleFrame(
                timestamp: cadence60Hz + stallDuration,
                targetTimestamp: cadence60Hz + stallDuration + cadence60Hz
            )

            await logic.flushBuffers()

            let counts = mockDestination.reportedCounts
            XCTAssertEqual(counts["frozenRenders"], 1)
            XCTAssertNil(counts["slowRenders"])
        }

        /// Verifies that a stall whose inter-frame gap is exactly the frozen threshold is classified
        /// as frozen, not slow.
        ///
        /// The second frame is constructed so the gap from the previous frame (not the target-relative
        /// lateness) equals `frozenFrameThreshold`. The frozen classification measures the inter-frame
        /// gap, matching the background watchdog, so both paths agree at the 700 ms boundary.
        func testStallAtExactFrozenThresholdIsFrozenNotSlow() async throws {
            let logic = try XCTUnwrap(logic)
            let mockDestination = try XCTUnwrap(mockDestination)

            await logic.handleFrame(timestamp: 0.0, targetTimestamp: cadence60Hz)

            // Gap from the previous frame is exactly the threshold: timestamp == gap, not cadence + gap.
            let gap = SlowFrameDetector.frozenFrameThreshold
            await logic.handleFrame(timestamp: gap, targetTimestamp: gap + cadence60Hz)

            await logic.flushBuffers()

            let counts = mockDestination.reportedCounts
            XCTAssertEqual(counts["frozenRenders"], 1)
            XCTAssertNil(counts["slowRenders"])
        }

        /// Verifies that a stall whose inter-frame gap is just below the frozen threshold is classified
        /// as slow, not frozen, proving the classification splits cleanly at the boundary.
        func testStallJustBelowFrozenThresholdIsSlowNotFrozen() async throws {
            let logic = try XCTUnwrap(logic)
            let mockDestination = try XCTUnwrap(mockDestination)

            await logic.handleFrame(timestamp: 0.0, targetTimestamp: cadence60Hz)

            // Gap just under the frozen threshold, still well past one cadence, so it is slow.
            let gap = SlowFrameDetector.frozenFrameThreshold - 0.001
            await logic.handleFrame(timestamp: gap, targetTimestamp: gap + cadence60Hz)

            await logic.flushBuffers()

            let counts = mockDestination.reportedCounts
            XCTAssertEqual(counts["slowRenders"], 1)
            XCTAssertNil(counts["frozenRenders"])
        }

        // MARK: Scenario 5 - flushing preserves signal names and count behavior

        /// Verifies that flushing preserves the existing signal names and count behavior, and does not
        /// duplicate reports across multiple flushes.
        func testFlushingPreservesSignalNamesWithoutDuplicateReports() async throws {
            let logic = try XCTUnwrap(logic)
            let mockDestination = try XCTUnwrap(mockDestination)

            await logic.handleFrame(timestamp: 0.0, targetTimestamp: cadence60Hz)
            await logic.handleFrame(timestamp: 2 * cadence60Hz, targetTimestamp: 3 * cadence60Hz) // slow

            await logic.flushBuffers()
            var counts = mockDestination.reportedCounts
            XCTAssertEqual(counts["slowRenders"], 1)
            XCTAssertNil(counts["frozenRenders"])

            // A second flush with nothing new pending must not duplicate the prior report.
            await logic.flushBuffers()
            counts = mockDestination.reportedCounts
            XCTAssertEqual(counts["slowRenders"], 1)
        }
    }
#endif // os(iOS) || os(tvOS) || os(visionOS)
