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
        // ARRANGE: The destination should not be called.
        mockDestination.onSend = { _, _ in
            XCTFail("The first frame should never trigger a slow frame report.")
        }

        await awaitDetectorStart()

        // ACT: Simulate only one frame.
        mockTicker.simulateFrame(timestamp: 0.0, duration: 1.0 / 60.0)
        await detector.flushBuffers()

        // ASSERT: The test passes if XCTFail is not called.
    }

    func test_slowFrame_isDetected() async throws {
        // ARRANGE
        let reportExpectation = XCTestExpectation(description: "Slow frame report received")
        mockDestination.onSend = { type, count in
            if type == "slowRenders" {
                XCTAssertEqual(count, 1)
                reportExpectation.fulfill()
            }
        }

        await awaitDetectorStart()

        let normalFrameDuration: TimeInterval = 1.0 / 60.0 // ~16.7ms

        // ACT
        // Frame 1: The baseline.
        mockTicker.simulateFrame(timestamp: 0.0, duration: normalFrameDuration)

        // Frame 2: An unambiguously slow frame.
        mockTicker.simulateFrame(timestamp: 0.100, duration: normalFrameDuration)

        // Let the async tasks complete, then flush the buffers to trigger the report.
        await Task.yield()
        await detector.flushBuffers()

        // ASSERT
        await fulfillment(of: [reportExpectation], timeout: 1.0)
    }

    func test_slowFrame_atBoundary_isDetected() async throws {
        // ARRANGE
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

        // ACT
        // Frame 1: The baseline
        mockTicker.simulateFrame(timestamp: 0.0, duration: expectedDuration)

        // Frame 2: Simulate a frame that took exactly the threshold amount of time.
        // Since our logic is >=, this should be detected as a slow frame.
        mockTicker.simulateFrame(timestamp: slowFrameThreshold, duration: expectedDuration)

        // Let the async tasks complete, then flush.
        await Task.yield()
        await detector.flushBuffers()

        // ASSERT
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
}

#endif // os(iOS) || os(tvOS) || os(visionOS)
