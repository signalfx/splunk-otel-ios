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
@testable import SplunkSlowFrameDetector
import XCTest
import SplunkCommon

final class SplunkSlowFrameDetectorTests: XCTestCase {
    // Note: This file will be populated with a comprehensive suite of unit tests
    // as part of the effort to improve the detector's testability.
    // The new tests will use mock objects to verify behavior.
}

// MARK: - Test Mocks

final class MockTicker: SlowFrameTicker {
    var onFrame: ((TimeInterval, TimeInterval) -> Void)?
    var started = false
    var stopped = false

    func start() {
        started = true
    }

    func stop() {
        stopped = true
    }

    func pause() {}
    func resume() {}

    func simulateFrame(timestamp: TimeInterval, duration: TimeInterval) {
        onFrame?(timestamp, duration)
    }
}

final class MockDestination: SlowFrameDetectorDestination {
    var onSend: ((String, Int) -> Void)?

    func send(type: String, count: Int, sharedState: AgentSharedState?) {
        onSend?(type, count)
    }
}
