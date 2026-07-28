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
import XCTest

#if os(iOS) || os(tvOS) || os(visionOS)
    import UIKit

    @testable import SplunkSlowFrameDetector

    final class MockTicker: SlowFrameTicker {
        @MainActor
        var started = false
        @MainActor
        var stopped = false
        @MainActor
        var startCallCount = 0
        @MainActor
        var pauseCallCount = 0
        @MainActor
        var resumeCallCount = 0

        @MainActor
        var onStart: (() -> Void)?
        @MainActor
        var onStop: (() -> Void)?
        @MainActor
        var onPause: (() -> Void)?
        @MainActor
        var onResume: (() -> Void)?

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
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                stopped = true
                onStop?()
            }
        }

        @MainActor
        func pause() {
            pauseCallCount += 1
            onPause?()
        }

        @MainActor
        func resume() {
            resumeCallCount += 1
            onResume?()
        }

        @MainActor
        func simulateFrame(timestamp: TimeInterval, targetTimestamp: TimeInterval) {
            continuation.yield((timestamp, targetTimestamp))
        }
    }
#endif
