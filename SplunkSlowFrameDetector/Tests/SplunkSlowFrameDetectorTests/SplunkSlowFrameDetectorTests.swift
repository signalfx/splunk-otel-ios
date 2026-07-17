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

            // This is the only test that uses the mockTicker's simulateFrame,
            // as it specifically tests the production path that consumes the AsyncStream.
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
    }
#endif // os(iOS) || os(tvOS) || os(visionOS)
