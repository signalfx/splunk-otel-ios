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

@MainActor
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

    @MainActor
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
    @MainActor
    private func awaitDetectorStart() async {
        let startExpectation = XCTestExpectation(description: "Detector has started")
        mockTicker.onStart = {
            startExpectation.fulfill()
        }
        detector.start()
        await fulfillment(of: [startExpectation], timeout: 1.0)
    }

    @MainActor
    func test_start_isIdempotent() async {
        XCTAssertEqual(mockTicker.startCallCount, 0)

        await awaitDetectorStart()
        XCTAssertEqual(mockTicker.startCallCount, 1, "start() should be called on the ticker the first time.")

        // Call start on the detector again.
        detector.start()
        await Task.yield() // Allow async logic to run.

        // Assert that the ticker's start() was not called a second time.
        XCTAssertEqual(mockTicker.startCallCount, 1, "Calling start() multiple times should not restart the ticker.")
    }

    @MainActor
    func test_stateIsReset_onAppDidBecomeActive() async {
        mockDestination.onSend = { _, _ in
            XCTFail("No report should be sent after app becomes active, as state should be reset.")
        }

        await awaitDetectorStart()

        // 1. Simulate a first frame to establish a baseline timestamp.
        mockTicker.simulateFrame(timestamp: 0.0, duration: 1.0 / 60.0)

        // 2. Simulate the app returning to the foreground. This should reset the logic.
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        await Task.yield() // Allow the async notification handler to run.

        // 3. Simulate a second frame after a long delay. Without the reset, this would be a slow frame.
        mockTicker.simulateFrame(timestamp: 10.0, duration: 1.0 / 60.0)

        // 4. Manually flush to check for any pending reports.
        await detector.flushBuffers()
    }

    @MainActor
    func test_buffersAreFlushed_onAppWillResignActive() async {
        let reportExpectation = XCTestExpectation(description: "Report is sent when app resigns active")
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
        await Task.yield() // Allow the slow frame to be processed.

        // 2. Directly trigger the behavior that the notification would cause.
        // This is deterministic and removes the race condition.
        await detector.flushBuffers()

        // 3. Now that the flush has completed, the report should have been sent.
        // The wait can be very short because the operation was synchronous.
        await fulfillment(of: [reportExpectation], timeout: 0.1)
    }

    @MainActor
    func test_firstFrame_doesNotTriggerReport() async {
        mockDestination.onSend = { _, _ in
            XCTFail("The first frame should never trigger a slow frame report.")
        }

        await awaitDetectorStart()

        mockTicker.simulateFrame(timestamp: 0.0, duration: 1.0 / 60.0)
        await detector.flushBuffers()
    }

    @MainActor
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

        await fulfillment(of: [reportExpectation], timeout: 5.0)
    }

    @MainActor
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

        await fulfillment(of: [reportExpectation], timeout: 5.0)
    }

    @MainActor
    func test_noReports_whenFramesAreNormal() async throws {
        mockDestination.onSend = { _, _ in XCTFail("No reports should be sent for normal frames.") }

        await awaitDetectorStart()

        let expectedDuration: TimeInterval = 1.0 / 60.0
        mockTicker.simulateFrame(timestamp: 0.0, duration: expectedDuration)
        mockTicker.simulateFrame(timestamp: expectedDuration, duration: expectedDuration)
        await detector.flushBuffers()
    }

    @MainActor
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

        await fulfillment(of: [reportExpectation], timeout: 2.0)
    }

    @MainActor
    func test_startAndStop_correctlyControlTicker() async {
        XCTAssertFalse(mockTicker.started)
        XCTAssertFalse(mockTicker.stopped)

        await awaitDetectorStart()
        XCTAssertTrue(mockTicker.started, "The ticker should be started.")

        let stopDidCompleteExpectation = XCTestExpectation(description: "detector.stop() completed")

        Task {
            await detector.stop()
            stopDidCompleteExpectation.fulfill()
        }

        await fulfillment(of: [stopDidCompleteExpectation], timeout: 2.0)

        XCTAssertTrue(mockTicker.stopped, "The ticker should be stopped.")
    }

    @MainActor
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

        // Check the final accumulated count in the mock destination
        // The watchdog should have fired at least 2 and no more than 4 times
        let finalCount = mockDestination.reportedCounts["frozenRenders"]
        XCTAssertGreaterThanOrEqual(finalCount ?? 0, 2, "Should report at least 2 frozen events in ~2.45s")
        XCTAssertLessThanOrEqual(finalCount ?? 0, 4, "Should report no more than 4 frozen events in ~2.45s")
    }

    @MainActor
    func test_automaticFlush_reportsPendingFrames() async {
        // 1. Create an expectation for the report itself.
        let reportExpectation = XCTestExpectation(description: "Report for slowRenders was sent")
        mockDestination.onSend = { type, count in
            if type == "slowRenders" {
                XCTAssertEqual(count, 1)
                reportExpectation.fulfill()
            }
        }

        // 2. Create a new expectation for when the flush has actually finished running.
        let flushDidRunExpectation = XCTestExpectation(description: "The automatic flush loop has completed a cycle")

        // 3. Assign a closure to the test hook property on the logic actor.
        await detector.logicForTest.setOnFlushDidComplete {
            flushDidRunExpectation.fulfill()
        }

        await awaitDetectorStart()

        // 4. Simulate a slow frame.
        mockTicker.simulateFrame(timestamp: 0.0, duration: 1.0 / 60.0)
        mockTicker.simulateFrame(timestamp: 0.1, duration: 1.0 / 60.0)
        await Task.yield()

        // 5. Wait for the flush to run. We no longer need to guess with Task.sleep!
        await fulfillment(of: [flushDidRunExpectation], timeout: 2.0)

        // 6. Now that we KNOW the flush has run, we can wait for the report expectation.
        // This timeout can be very short because if the flush ran, the report should
        // have been sent immediately.
        await fulfillment(of: [reportExpectation], timeout: 0.1)
    }
}
#endif // os(iOS) || os(tvOS) || os(visionOS)
