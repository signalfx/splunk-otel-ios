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

import Foundation
import SplunkCommon
import XCTest

#if os(iOS) || os(tvOS) || os(visionOS)

    import QuartzCore
    import UIKit

    @testable import SplunkSlowFrameDetector

    // MARK: - SlowFrameDetectorTests

    /// Integration tests for the `SlowFrameDetector` facade: ticker lifecycle control and the production
    /// `AsyncStream` path.
    ///
    /// Deterministic detection-algorithm tests live in `SlowFrameLogicTests`.
    @MainActor
    final class SlowFrameDetectorTests: XCTestCase {

        // MARK: - Test Properties

        private var detector: SlowFrameDetector?
        private var mockTicker: MockTicker?
        private var mockDestination: MockDestination?

        private let cadence60Hz: TimeInterval = 1.0 / 60.0


        // MARK: - Test Lifecycle

        override func setUp() async throws {
            try await super.setUp()
            let destination = MockDestination()
            mockDestination = destination

            let ticker = MockTicker()
            mockTicker = ticker
            detector = SlowFrameDetector(ticker: ticker, destination: destination)
        }

        override func tearDown() async throws {
            if let mockTicker, !mockTicker.stopped {
                await detector?.stop()
            }
            detector = nil
            mockTicker = nil
            mockDestination = nil

            try await super.tearDown()
        }


        // MARK: - Integration Tests

        func testStartIsIdempotent() async throws {
            XCTAssertFalse(mockTicker?.started ?? true)

            try await pauseUntilDetectorStart()
            XCTAssertEqual(mockTicker?.startCallCount, 1)

            detector?.start()
            await Task.yield()

            XCTAssertEqual(mockTicker?.startCallCount, 1)
        }

        func testStartAndStopCorrectlyControlTicker() async throws {
            XCTAssertFalse(mockTicker?.started ?? true)
            XCTAssertFalse(mockTicker?.stopped ?? true)

            try await pauseUntilDetectorStart()
            XCTAssertTrue(mockTicker?.started ?? false)

            let stopExpectation = XCTestExpectation(description: "Ticker was stopped")
            mockTicker?.onStop = { stopExpectation.fulfill() }

            Task {
                await self.detector?.stop()
            }

            await fulfillment(of: [stopExpectation], timeout: 2.0)
            XCTAssertTrue(mockTicker?.stopped ?? false)
        }

        /// Verifies that lifecycle notifications flow through the detector's observer and ticker,
        /// and that a stale pre-background tick delivered after foregrounding cannot seed the new
        /// frame baseline or produce a spurious frozen render.
        func testLifecycleNotificationsFenceStaleFramesAcrossBackgroundTransition() async throws {
            let mockDestination = try XCTUnwrap(mockDestination)
            let mockTicker = try XCTUnwrap(mockTicker)
            let detector = try XCTUnwrap(detector)

            try await pauseUntilDetectorStart()

            let pauseExpectation = XCTestExpectation(description: "Ticker was paused")
            mockTicker.onPause = {
                pauseExpectation.fulfill()
            }

            NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
            await fulfillment(of: [pauseExpectation], timeout: 1.0)

            let resumeExpectation = XCTestExpectation(description: "Ticker was resumed")
            mockTicker.onResume = {
                resumeExpectation.fulfill()
            }

            NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
            await fulfillment(of: [resumeExpectation], timeout: 1.0)

            XCTAssertEqual(mockTicker.pauseCallCount, 1)
            XCTAssertEqual(mockTicker.resumeCallCount, 1)

            // This timestamp predates the activation cutoff and represents a pre-background tick
            // that remained buffered until after the app became active.
            let staleTimestamp: TimeInterval = 1.0
            mockTicker.simulateFrame(
                timestamp: staleTimestamp,
                targetTimestamp: staleTimestamp + cadence60Hz
            )

            // The first current frame establishes the new baseline. The following frame misses one
            // presentation opportunity, proving the stream continued normally after the stale tick.
            let freshTimestamp = CACurrentMediaTime()
            mockTicker.simulateFrame(
                timestamp: freshTimestamp,
                targetTimestamp: freshTimestamp + cadence60Hz
            )
            mockTicker.simulateFrame(
                timestamp: freshTimestamp + 2 * cadence60Hz,
                targetTimestamp: freshTimestamp + 3 * cadence60Hz
            )

            try await waitUntilSlowFrameCount(atLeast: 1, logic: detector.logicForTest)
            await detector.flushBuffers()

            let counts = mockDestination.reportedCounts
            XCTAssertEqual(counts["slowRenders"], 1)
            XCTAssertNil(counts["frozenRenders"])
        }

        /// Verifies that the full detector correctly reports pending frames via the automatic flush loop.
        func testIntegrationAutomaticFlushReportsPendingFrames() async throws {
            let mockDestination = try XCTUnwrap(mockDestination)
            let mockTicker = try XCTUnwrap(mockTicker)
            let detector = try XCTUnwrap(detector)

            let reportExpectation = XCTestExpectation(description: "Report for slowRenders was sent")
            mockDestination.setOnSend { type, count in
                if type == "slowRenders" {
                    XCTAssertEqual(count, 1)
                    reportExpectation.fulfill()
                }
            }

            // Start the full detector for this integration test
            let startExpectation = XCTestExpectation(description: "Detector has started")
            mockTicker.onStart = {
                startExpectation.fulfill()
            }
            detector.start()
            await fulfillment(of: [startExpectation], timeout: 1.0)

            // Drive the production path that consumes the ticker's AsyncStream.
            mockTicker.simulateFrame(timestamp: 0.0, targetTimestamp: cadence60Hz)
            mockTicker.simulateFrame(timestamp: 2 * cadence60Hz, targetTimestamp: 3 * cadence60Hz)

            await fulfillment(of: [reportExpectation], timeout: 1.5)
        }

        // MARK: - Helper Methods

        private func pauseUntilDetectorStart() async throws {
            let mockTicker = try XCTUnwrap(mockTicker)
            let detector = try XCTUnwrap(detector)

            let startExpectation = XCTestExpectation(description: "Detector has started")
            mockTicker.onStart = {
                startExpectation.fulfill()
            }
            detector.start()

            await fulfillment(of: [startExpectation], timeout: 1.0)
        }

        /// Waits for frames yielded by `MockTicker` to traverse the detector's production
        /// `AsyncStream` path and reach `SlowFrameLogic`.
        private func waitUntilSlowFrameCount(atLeast count: Int, logic: SlowFrameLogic) async throws {
            for _ in 0 ..< 50 {
                if await logic.testSlowFrameCount >= count {
                    return
                }

                try await Task.sleep(nanoseconds: 10_000_000)
            }

            XCTFail("Timed out waiting for \(count) buffered slow frame(s).")
        }
    }
#endif // os(iOS) || os(tvOS) || os(visionOS)
