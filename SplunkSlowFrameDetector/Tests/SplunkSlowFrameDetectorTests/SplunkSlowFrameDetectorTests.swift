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

import SplunkCommon
import XCTest
#if os(iOS) || os(tvOS) || os(visionOS)
@testable import SplunkSlowFrameDetector
import UIKit

final class MockTicker: SlowFrameTicker {
    var onFrame: ((TimeInterval, TimeInterval) -> Void)?
    var started = false
    var stopped = false
    var startCallCount = 0

    var onStart: (() -> Void)?

    func start() {
        started = true
        startCallCount += 1
        onStart?()
    }
    func stop() { stopped = true }
    func pause() {}
    func resume() {}

    func simulateFrame(timestamp: TimeInterval, duration: TimeInterval) {
        onFrame?(timestamp, duration)
    }
}

private class MockDestination: SlowFrameDetectorDestination {
    // This dictionary will store the accumulated counts.
    var reportedCounts: [String: Int] = [:]
    var onSend: ((String, Int) -> Void)?

    func send(type: String, count: Int, sharedState: AgentSharedState?) async {
        // Accumulate the count for the given type.
        reportedCounts[type, default: 0] += count
        // Call the optional closure for tests that still need it.
        onSend?(type, count)
    }
}

final class SlowFrameDetectorTests: XCTestCase {

    private var mockTicker: MockTicker!
    private var detector: SlowFrameDetector!
    private var mockDestination: MockDestination!

    override func setUp() {
        super.setUp()
        mockTicker = MockTicker()
        mockDestination = MockDestination()
        detector = SlowFrameDetector(ticker: mockTicker, destinationFactory: { self.mockDestination })
    }

    override func tearDown() async throws {
        await detector.stop()

        detector = nil
        mockDestination = nil
        mockTicker = nil

        try await super.tearDown()
    }

    // Helper function to wait for the detector to start up.
    private func awaitDetectorStart() async {
        let startExpectation = XCTestExpectation(description: "Detector has started")
        mockTicker.onStart = {
            startExpectation.fulfill()
        }
        detector.start()
        await fulfillment(of: [startExpectation], timeout: 1.0)
    }

    func test_firstFrame_doesNotTriggerReport() async {
        mockDestination.onSend = { _, _ in
            XCTFail("The first frame should never trigger a slow frame report.")
        }

        await awaitDetectorStart()

        // Simulate only one frame.
        mockTicker.simulateFrame(timestamp: 0.0, duration: 1.0 / 60.0)
        await detector.flushBuffers()
    }

    func test_slowFrame_isDetected() async throws {
        let reportExpectation = XCTestExpectation(description: "Slow frame report received")
        mockDestination.onSend = { type, count in
            if type == "slowRenders" {
                XCTAssertEqual(count, 1)
                reportExpectation.fulfill()
            }
        }

        await awaitDetectorStart()

        let normalFrameDuration: TimeInterval = 1.0 / 60.0 // ~16.7ms

        // Frame 1: The baseline.
        mockTicker.simulateFrame(timestamp: 0.0, duration: normalFrameDuration)

        // Frame 2: An unambiguously slow frame.
        mockTicker.simulateFrame(timestamp: 0.100, duration: normalFrameDuration)

        // Let the async tasks complete, then flush the buffers to trigger the report.
        await Task.yield()
        await detector.flushBuffers()

        await fulfillment(of: [reportExpectation], timeout: 1.0)
    }

    func test_slowFrame_atBoundary_isDetected() async throws {
        let reportExpectation = XCTestExpectation(description: "Slow frame report at boundary received")
        mockDestination.onSend = { type, count in
            if type == "slowRenders" {
                XCTAssertEqual(count, 1)
                reportExpectation.fulfill()
            }
        }

        await awaitDetectorStart()

        // 1. Define the parameters clearly
        let expectedDuration: TimeInterval = 1.0 / 60.0
        let toleranceValue = expectedDuration * (SlowFrameDetector.slowFrameTolerancePercentage / 100.0)

        // 2. Calculate the exact threshold
        let slowFrameThreshold = expectedDuration + toleranceValue

        // Frame 1: The baseline
        mockTicker.simulateFrame(timestamp: 0.0, duration: expectedDuration)

        // Frame 2: Simulate a frame that took exactly the threshold amount of time.
        // Since our logic is >=, this should be detected as a slow frame.
        mockTicker.simulateFrame(timestamp: slowFrameThreshold, duration: expectedDuration)

        // Let the async tasks complete, then flush.
        await Task.yield()
        await detector.flushBuffers()

        await fulfillment(of: [reportExpectation], timeout: 1.0)
    }

    func test_noReports_whenFramesAreNormal() async throws {
        mockDestination.onSend = { _, _ in XCTFail("No reports should be sent for normal frames.") }

        await awaitDetectorStart()

        let expectedDuration: TimeInterval = 1.0 / 60.0
        mockTicker.simulateFrame(timestamp: 0.0, duration: expectedDuration)
        mockTicker.simulateFrame(timestamp: expectedDuration, duration: expectedDuration)
        await detector.flushBuffers()
    }

    func test_frozenFrame_isDetected_whenFramesStop() async throws {
        let reportExpectation = XCTestExpectation(description: "Frozen frame report received")
        mockDestination.onSend = { type, count in
            if type == "frozenRenders" {
                XCTAssertGreaterThanOrEqual(count, 1)
                reportExpectation.fulfill()
            }
        }

        await awaitDetectorStart()

        let hangTime = SlowFrameDetector.frozenFrameThreshold

        mockTicker.simulateFrame(timestamp: 0.0, duration: 1.0 / 60.0)
        try await Task.sleep(nanoseconds: UInt64((hangTime + 0.1) * 1_000_000_000))
        await detector.flushBuffers()

        await fulfillment(of: [reportExpectation], timeout: 1.0)
    }

    func test_longFreeze_reportsMultipleEvents() async throws {
        await awaitDetectorStart()

        // 1. Simulate one frame to establish a heartbeat.
        mockTicker.simulateFrame(timestamp: 0.0, duration: 1.0 / 60.0)
        await Task.yield() // Ensure the heartbeat is set before sleeping.

        // 2. Sleep for a period that allows the watchdog AND the automatic flush to run.
        // We will sleep for ~2.5 seconds.
        // Watchdog runs at: ~0.7s, ~1.4s, ~2.1s (3 times)
        // Auto-flush runs at: ~1.0s, ~2.0s (2 times)
        let hangTime = SlowFrameDetector.frozenFrameThreshold * 3.5 // ~2.45s
        try await Task.sleep(nanoseconds: UInt64(hangTime * 1_000_000_000))

        // 3. Manually flush any remaining counts at the end of the test.
        await detector.flushBuffers()

        // Check the final accumulated count in the mock destination.
        // The watchdog should have fired 3 times.
        let finalCount = mockDestination.reportedCounts["frozenRenders"]
        XCTAssertEqual(finalCount, 3, "The total count of frozen events should be 3 after ~2.45s.")
    }

    func test_automaticFlush_reportsPendingFrames() async {
        let reportExpectation = XCTestExpectation(description: "Automatic flush loop sends report")
        mockDestination.onSend = { type, count in
            if type == "slowRenders" {
                XCTAssertEqual(count, 1)
                reportExpectation.fulfill()
            }
        }
        await awaitDetectorStart()

        // 1. Simulate a slow frame.
        mockTicker.simulateFrame(timestamp: 0.0, duration: 1.0 / 60.0)
        mockTicker.simulateFrame(timestamp: 0.1, duration: 1.0 / 60.0)

        // FIX: Yield to ensure the async tasks to process the frames have completed.
        await Task.yield()

        // 2. Wait for longer than the automatic flush interval (1 second).
        // DO NOT call flushBuffers() manually.
        try? await Task.sleep(nanoseconds: 1_100_000_000)

        // The expectation should be fulfilled by the automatic flush loop.
        await fulfillment(of: [reportExpectation], timeout: 1.5)
    }
}

#endif // os(iOS) || os(tvOS) || os(visionOS)
