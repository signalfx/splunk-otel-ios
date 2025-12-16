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

    final class MockTicker: SlowFrameTicker {
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

    actor MockDestination: SlowFrameDetectorDestination {
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

        func setOnSend(_ handler: ((String, Int) -> Void)?) async {
            onSend = handler
        }
    }
#endif
