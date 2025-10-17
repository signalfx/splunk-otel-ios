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

    // MARK: - Mock Ticker

    private final class MockTicker: SlowFrameTicker {
        @MainActor
        var started = false
        @MainActor
        var stopped = false
        @MainActor
        var startCallCount = 0

        @MainActor
        var onStart: (() -> Void)?
        @MainActor
        var onStop: (() -> Void)?

        let onFrameStream: AsyncStream<(TimeInterval, TimeInterval)>
        private let continuation: AsyncStream<(TimeInterval, TimeInterval)>.Continuation

        init() {
            let (stream, continuation) = AsyncStream.makeStream(of: (TimeInterval, TimeInterval).self)
            onFrameStream = stream
            self.continuation = continuation
        }

        @MainActor
        func start() {
            started = true
            startCallCount += 1
            onStart?()
        }

        func stop() {
            // This function is non-isolated to match the protocol
            // To safely modify the @MainActor properties, we dispatch to the main queue
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                stopped = true
                onStop?()
            }
        }

        @MainActor
        func pause() {}

        @MainActor
        func resume() {}

        @MainActor
        func simulateFrame(timestamp: TimeInterval, duration: TimeInterval) {
            continuation.yield((timestamp, duration))
        }
    }

    // MARK: - Mock Destination

    private actor MockDestination: SlowFrameDetectorDestination {
        // This dictionary will store the accumulated counts.
        var reportedCounts: [String: Int] = [:]
        private var onSend: ((String, Int) -> Void)?

        func send(type: String, count: Int, sharedState _: AgentSharedState?) async {
            // Yield to satisfy the async requirement of the protocol in this mock implementation.
            await Task.yield()
            // Accumulate the count for the given type
            reportedCounts[type, default: 0] += count
            // Call the optional closure for tests that still need it
            onSend?(type, count)
        }

        func setOnSend(_ handler: ((String, Int) -> Void)?) {
            onSend = handler
        }
    }

    // MARK: - SlowFrameDetectorTests

    @MainActor
    final class SlowFrameDetectorTests: XCTestCase {

        // MARK: - Test Properties

        private var logic: SlowFrameLogic?
        private var mockDestination: MockDestination?

        // For integration tests that need the full detector
        private var detector: SlowFrameDetector?
        private var mockTicker: MockTicker?


        // MARK: - Test Lifecycle

        override func setUp() async throws {
            try await super.setUp()
            let destination = MockDestination()
            mockDestination = destination
            logic = SlowFrameLogic(destinationFactory: { destination })

            // Initialize the full detector for integration tests
            let ticker = MockTicker()
            mockTicker = ticker
            detector = SlowFrameDetector(ticker: ticker, destinationFactory: { destination })

            try await logic?.start()
        }

        override func tearDown() async throws {
            await logic?.stop()
            logic = nil
            mockDestination = nil

            // Tear down the full detector
            if let mockTicker, !mockTicker.stopped {
                await detector?.stop()
            }
            detector = nil
            mockTicker = nil

            try await super.tearDown()
        }


        // MARK: - Lifecycle Notification Tests

        /// Verifies that the logic state is reset when the app becomes active.
        func test_stateIsReset_onAppDidBecomeActive() async throws {
            let logic = try XCTUnwrap(logic)
            let mockDestination = try XCTUnwrap(mockDestination)

            await logic.handleFrame(timestamp: 0.0, duration: 1.0 / 60.0)
            await logic.handleFrame(timestamp: 0.1, duration: 1.0 / 60.0) // This would normally be a slow frame

            await logic.appDidBecomeActive()

            // This frame should now be treated as the first frame, not triggering a slow frame
            await logic.handleFrame(timestamp: 10.0, duration: 1.0 / 60.0)

            await logic.flushBuffers()

            let counts = await mockDestination.reportedCounts
            XCTAssertTrue(counts.isEmpty, "No reports should be sent after app becomes active.")
        }

        /// Verifies that pending buffers are flushed when the app resigns active.
        func test_buffersAreFlushed_onAppWillResignActive() async throws {
            let logic = try XCTUnwrap(logic)
            let mockDestination = try XCTUnwrap(mockDestination)

            await logic.handleFrame(timestamp: 0.0, duration: 1.0 / 60.0)
            await logic.handleFrame(timestamp: 0.1, duration: 1.0 / 60.0)

            // This will trigger flushBuffers internally
            await logic.appWillResignActive()

            let counts = await mockDestination.reportedCounts
            XCTAssertEqual(counts["slowRenders"], 1)
        }


        // MARK: - Frame Detection Tests

        /// Verifies that the very first frame processed does not trigger a report.
        func test_firstFrame_doesNotTriggerReport() async throws {
            let logic = try XCTUnwrap(logic)
            let mockDestination = try XCTUnwrap(mockDestination)

            await logic.handleFrame(timestamp: 0.0, duration: 1.0 / 60.0)
            await logic.flushBuffers()

            let counts = await mockDestination.reportedCounts
            XCTAssertTrue(counts.isEmpty)
        }

        /// Verifies that a clearly slow frame is detected and reported.
        func test_slowFrame_isDetected() async throws {
            let logic = try XCTUnwrap(logic)
            let mockDestination = try XCTUnwrap(mockDestination)
            let normalFrameDuration: TimeInterval = 1.0 / 60.0

            await logic.handleFrame(timestamp: 0.0, duration: normalFrameDuration)
            await logic.handleFrame(timestamp: 0.100, duration: normalFrameDuration)

            await logic.flushBuffers()

            let counts = await mockDestination.reportedCounts
            XCTAssertEqual(counts["slowRenders"], 1)
        }

        /// Verifies that a frame at the exact slow-frame threshold is correctly detected.
        func test_slowFrame_atBoundary_isDetected() async throws {
            let logic = try XCTUnwrap(logic)
            let mockDestination = try XCTUnwrap(mockDestination)
            let expectedDuration: TimeInterval = 1.0 / 60.0
            let toleranceValue = expectedDuration * (SlowFrameDetector.slowFrameTolerancePercentage / 100.0)
            let slowFrameThreshold = expectedDuration + toleranceValue

            await logic.handleFrame(timestamp: 0.0, duration: expectedDuration)
            await logic.handleFrame(timestamp: slowFrameThreshold, duration: expectedDuration)

            await logic.flushBuffers()

            let counts = await mockDestination.reportedCounts
            XCTAssertEqual(counts["slowRenders"], 1)
        }

        /// Verifies that no reports are sent when frame times are normal.
        func test_noReports_whenFramesAreNormal() async throws {
            let logic = try XCTUnwrap(logic)
            let mockDestination = try XCTUnwrap(mockDestination)
            let expectedDuration: TimeInterval = 1.0 / 60.0

            await logic.handleFrame(timestamp: 0.0, duration: expectedDuration)
            await logic.handleFrame(timestamp: expectedDuration, duration: expectedDuration)

            await logic.flushBuffers()

            let counts = await mockDestination.reportedCounts
            XCTAssertTrue(counts.isEmpty)
        }

        /// Verifies that a frozen frame is detected when the ticker stops firing.
        func test_frozenFrame_isDetected_whenFramesStop() async throws {
            let logic = try XCTUnwrap(logic)
            let mockDestination = try XCTUnwrap(mockDestination)
            let hangTime = SlowFrameDetector.frozenFrameThreshold // 0.7 seconds

            await logic.handleFrame(timestamp: 0.0, duration: 1.0 / 60.0)

            // Create an expectation that the frozenFrameCount becomes 1
            let frozenFrameDetectedExpectation = XCTestExpectation(description: "Frozen frame detected by watchdog")

            // Monitor the frozenFrameCount in a background task
            Task {
                var count = 0
                while count < 1, !Task.isCancelled {
                    count = await logic.testFrozenFrameCount
                    if count >= 1 {
                        frozenFrameDetectedExpectation.fulfill()
                        break
                    }
                    try? await Task.sleep(nanoseconds: 10_000_000) // Check every 10ms
                }
            }

            try await Task.sleep(nanoseconds: UInt64((hangTime + 0.05) * 1_000_000_000))

            await fulfillment(of: [frozenFrameDetectedExpectation], timeout: 1.0)

            await logic.flushBuffers()

            let counts = await mockDestination.reportedCounts
            XCTAssertEqual(counts["frozenRenders"], 1, "Expected exactly one frozen render to be reported.")
        }

        /// Verifies that a long freeze correctly reports multiple frozen frame events.
        func test_longFreeze_reportsMultipleEvents() async throws {
            let logic = try XCTUnwrap(logic)
            let mockDestination = try XCTUnwrap(mockDestination)
            let hangTime = SlowFrameDetector.frozenFrameThreshold * 3.5

            await logic.handleFrame(timestamp: 0.0, duration: 1.0 / 60.0)

            try await Task.sleep(nanoseconds: UInt64(hangTime * 1_000_000_000))

            await logic.flushBuffers()

            let counts = await mockDestination.reportedCounts
            let finalCount = counts["frozenRenders"]
            XCTAssertGreaterThanOrEqual(finalCount ?? 0, 2)
            XCTAssertLessThanOrEqual(finalCount ?? 0, 4)
        }

        // MARK: - Integration Tests

        /// Verifies that the full detector correctly reports pending frames via the automatic flush loop.
        func test_integration_automaticFlush_reportsPendingFrames() async throws {
            let mockDestination = try XCTUnwrap(mockDestination)
            let mockTicker = try XCTUnwrap(mockTicker)
            let detector = try XCTUnwrap(detector)

            let reportExpectation = XCTestExpectation(description: "Report for slowRenders was sent")
            await mockDestination.setOnSend { type, count in
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
            mockTicker.simulateFrame(timestamp: 0.0, duration: 1.0 / 60.0)
            mockTicker.simulateFrame(timestamp: 0.1, duration: 1.0 / 60.0)

            await fulfillment(of: [reportExpectation], timeout: 1.5)
        }
    }

    extension SlowFrameLogic {
        #if DEBUG
            func sync() {}
        #endif
    }
#endif // os(iOS) || os(tvOS) || os(visionOS)
