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
        var onFrame: (@MainActor (TimeInterval, TimeInterval) async -> Void)?
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
        func simulateFrame(timestamp: TimeInterval, duration: TimeInterval) async {
            await onFrame?(timestamp, duration)
        }
    }

    // MARK: - Mock Destination

    private actor MockDestination: SlowFrameDetectorDestination {
        // This dictionary will store the accumulated counts.
        var reportedCounts: [String: Int] = [:]
        private var onSend: ((String, Int) -> Void)?

        func send(type: String, count: Int, sharedState _: AgentSharedState?) {
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

        private var mockTicker: MockTicker?
        private var detector: SlowFrameDetector?
        private var mockDestination: MockDestination?


        // MARK: - Test Lifecycle

        override func setUp() {
            super.setUp()
            mockTicker = MockTicker()
            let currentMock = MockDestination()
            mockDestination = currentMock
            detector = SlowFrameDetector(ticker: mockTicker, destinationFactory: { currentMock })
        }

        override func tearDown() async throws {
            // Only stop the detector if the test itself hasn't already stopped it.
            if let mockTicker, !mockTicker.stopped {
                let expectation = XCTestExpectation(description: "TearDown Stop Expectation")
                mockTicker.onStop = { expectation.fulfill() }

                // Run stop in a detached task to avoid blocking the MainActor test method
                Task.detached {
                    await self.detector?.stop()
                }

                await fulfillment(of: [expectation], timeout: 2.0)
            }

            detector = nil
            mockDestination = nil
            mockTicker = nil

            try await super.tearDown()
        }


        // MARK: - Helper Methods

        private func pauseUntilDetectorStart() async {
            let startExpectation = XCTestExpectation(description: "Detector has started")
            mockTicker?.onStart = {
                startExpectation.fulfill()
            }
            detector?.start()
            await fulfillment(of: [startExpectation], timeout: 1.0)
        }


        // MARK: - Start/Stop Tests

        /// Verifies that calling `start()` multiple times is idempotent.
        func test_start_isIdempotent() async {
            XCTAssertFalse(mockTicker?.started ?? true)

            await pauseUntilDetectorStart()
            XCTAssertEqual(mockTicker?.startCallCount, 1)

            detector?.start()
            await Task.yield()

            XCTAssertEqual(mockTicker?.startCallCount, 1)
        }

        /// Verifies that `start()` and `stop()` correctly control the ticker's state.
        func test_startAndStop_correctlyControlTicker() async {
            XCTAssertFalse(mockTicker?.started ?? true)
            XCTAssertFalse(mockTicker?.stopped ?? true)

            await pauseUntilDetectorStart()
            XCTAssertTrue(mockTicker?.started ?? false)

            let tickerStopExpectation = XCTestExpectation(description: "Ticker was stopped")
            mockTicker?.onStop = { tickerStopExpectation.fulfill() }

            Task.detached {
                await self.detector?.stop()
            }

            await fulfillment(of: [tickerStopExpectation], timeout: 2.0)
            XCTAssertTrue(mockTicker?.stopped ?? false)
        }


        // MARK: - Lifecycle Notification Tests

        /// Verifies that the logic state is reset when the app becomes active.
        func test_stateIsReset_onAppDidBecomeActive() async {
            await pauseUntilDetectorStart()

            await mockTicker?.simulateFrame(timestamp: 0.0, duration: 1.0 / 60.0)

            NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
            await Task.yield() // Allow notification to be processed

            await mockTicker?.simulateFrame(timestamp: 10.0, duration: 1.0 / 60.0)

            await detector?.flushBuffers()

            let counts = await mockDestination?.reportedCounts
            XCTAssertTrue(counts?.isEmpty ?? true, "No reports should be sent after app becomes active.")
        }

        /// Verifies that pending buffers are flushed when the app resigns active.
        func test_buffersAreFlushed_onAppWillResignActive() async {
            await pauseUntilDetectorStart()

            await mockTicker?.simulateFrame(timestamp: 0.0, duration: 1.0 / 60.0)
            await mockTicker?.simulateFrame(timestamp: 0.1, duration: 1.0 / 60.0)

            await detector?.flushBuffers()

            let counts = await mockDestination?.reportedCounts
            XCTAssertEqual(counts?["slowRenders"], 1)
        }


        // MARK: - Frame Detection Tests

        /// Verifies that the very first frame processed does not trigger a report.
        func test_firstFrame_doesNotTriggerReport() async {
            await pauseUntilDetectorStart()

            await mockTicker?.simulateFrame(timestamp: 0.0, duration: 1.0 / 60.0)

            await detector?.flushBuffers()

            let counts = await mockDestination?.reportedCounts
            XCTAssertTrue(counts?.isEmpty ?? true)
        }

        /// Verifies that a clearly slow frame is detected and reported.
        func test_slowFrame_isDetected() async throws {
            await pauseUntilDetectorStart()

            let normalFrameDuration: TimeInterval = 1.0 / 60.0

            await mockTicker?.simulateFrame(timestamp: 0.0, duration: normalFrameDuration)
            await mockTicker?.simulateFrame(timestamp: 0.100, duration: normalFrameDuration)

            await detector?.flushBuffers()

            let counts = await mockDestination?.reportedCounts
            XCTAssertEqual(counts?["slowRenders"], 1)
        }

        /// Verifies that a frame at the exact slow-frame threshold is correctly detected.
        func test_slowFrame_atBoundary_isDetected() async throws {
            await pauseUntilDetectorStart()

            let expectedDuration: TimeInterval = 1.0 / 60.0
            let toleranceValue = expectedDuration * (SlowFrameDetector.slowFrameTolerancePercentage / 100.0)
            let slowFrameThreshold = expectedDuration + toleranceValue

            await mockTicker?.simulateFrame(timestamp: 0.0, duration: expectedDuration)
            await mockTicker?.simulateFrame(timestamp: slowFrameThreshold, duration: expectedDuration)

            await detector?.flushBuffers()

            let counts = await mockDestination?.reportedCounts
            XCTAssertEqual(counts?["slowRenders"], 1)
        }

        /// Verifies that no reports are sent when frame times are normal.
        func test_noReports_whenFramesAreNormal() async throws {
            await pauseUntilDetectorStart()

            let expectedDuration: TimeInterval = 1.0 / 60.0
            await mockTicker?.simulateFrame(timestamp: 0.0, duration: expectedDuration)
            await mockTicker?.simulateFrame(timestamp: expectedDuration, duration: expectedDuration)

            await detector?.flushBuffers()

            let counts = await mockDestination?.reportedCounts
            XCTAssertTrue(counts?.isEmpty ?? true)
        }

        /// Verifies that a frozen frame is detected when the ticker stops firing.
        func test_frozenFrame_isDetected_whenFramesStop() async throws {
            await pauseUntilDetectorStart()

            let hangTime = SlowFrameDetector.frozenFrameThreshold // 0.7 seconds

            await mockTicker?.simulateFrame(timestamp: 0.0, duration: 1.0 / 60.0)

            // Create an expectation that the frozenFrameCount becomes 1
            let frozenFrameDetectedExpectation = XCTestExpectation(description: "Frozen frame detected by watchdog")

            // Monitor the frozenFrameCount in a background task
            // This task will fulfill the expectation once frozenFrameCount is 1.
            Task {
                var count = 0
                while count < 1, !Task.isCancelled {
                    // Access the test-only property on the actor
                    count = await detector?.logicForTest.testFrozenFrameCount ?? 0
                    if count >= 1 {
                        frozenFrameDetectedExpectation.fulfill()
                        break
                    }
                    // Poll frequently to catch the change quickly
                    try? await Task.sleep(nanoseconds: 10_000_000) // Check every 10ms
                }
            }

            // Simulate the passage of time required for the watchdog to trigger.
            // This sleep ensures CACurrentMediaTime() in runWatchdog advances sufficiently.
            // Using a duration slightly longer than hangTime but less than runFlushLoop's 1s interval.
            try await Task.sleep(nanoseconds: UInt64((hangTime + 0.05) * 1_000_000_000)) // Sleep for 0.75 seconds

            // Wait for the watchdog to detect the frozen frame and update the count.
            // This synchronizes the test with the internal state change.
            await fulfillment(of: [frozenFrameDetectedExpectation], timeout: 1.0) // Timeout should be > hangTime

            // Now that we are sure frozenFrameCount is 1, explicitly flush the buffers.
            await detector?.flushBuffers()

            let counts = await mockDestination?.reportedCounts
            XCTAssertEqual(counts?["frozenRenders"], 1, "Expected exactly one frozen render to be reported.")
        }

        /// Verifies that a long freeze correctly reports multiple frozen frame events.
        func test_longFreeze_reportsMultipleEvents() async throws {
            await pauseUntilDetectorStart()

            await mockTicker?.simulateFrame(timestamp: 0.0, duration: 1.0 / 60.0)

            let hangTime = SlowFrameDetector.frozenFrameThreshold * 3.5
            try await Task.sleep(nanoseconds: UInt64(hangTime * 1_000_000_000))

            await detector?.flushBuffers()

            let counts = await mockDestination?.reportedCounts
            let finalCount = counts?["frozenRenders"]
            XCTAssertGreaterThanOrEqual(finalCount ?? 0, 2)
            XCTAssertLessThanOrEqual(finalCount ?? 0, 4)
        }

        /// Verifies that the automatic flush loop correctly reports pending frames.
        func test_automaticFlush_reportsPendingFrames() async {
            let reportExpectation = XCTestExpectation(description: "Report for slowRenders was sent")
            await mockDestination?
                .setOnSend { type, count in
                    if type == "slowRenders" {
                        XCTAssertEqual(count, 1)
                        reportExpectation.fulfill()
                    }
                }

            await pauseUntilDetectorStart()

            await mockTicker?.simulateFrame(timestamp: 0.0, duration: 1.0 / 60.0)
            await mockTicker?.simulateFrame(timestamp: 0.1, duration: 1.0 / 60.0)

            await fulfillment(of: [reportExpectation], timeout: 1.5)
        }
    }

    extension SlowFrameLogic {
        #if DEBUG
            func sync() {}
        #endif
    }
#endif // os(iOS) || os(tvOS) || os(visionOS)
