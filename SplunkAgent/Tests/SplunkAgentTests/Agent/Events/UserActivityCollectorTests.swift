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

@testable import SplunkAgent

final class UserActivityCollectorTests: XCTestCase {

    func testFlushReturnsOnlyWindowTimestamps() {
        let collector = UserActivityCollector()
        collector.record(at: Date(timeIntervalSince1970: 1.0)) // 1000 ms
        collector.record(at: Date(timeIntervalSince1970: 2.0)) // 2000 ms
        collector.record(at: Date(timeIntervalSince1970: 3.0)) // 3000 ms

        let flushed = collector.flush(startMs: 1_500, endMs: 2_500)

        XCTAssertEqual(flushed, [2_000])
    }

    func testFlushDoesNotRemoveTimestampsOutsideWindow() {
        let collector = UserActivityCollector()
        collector.record(at: Date(timeIntervalSince1970: 1.0))
        collector.record(at: Date(timeIntervalSince1970: 2.0))
        collector.record(at: Date(timeIntervalSince1970: 3.0))

        _ = collector.flush(startMs: 1_500, endMs: 2_500)
        let remaining = collector.flush(startMs: 500, endMs: 4_000)

        XCTAssertEqual(remaining.sorted(), [1_000, 3_000])
    }

    func testConcurrentFlushesDoNotStealEachOthersTimestamps() {
        let collector = UserActivityCollector()
        collector.record(at: Date(timeIntervalSince1970: 1.0)) // segment A: [1000,2000]
        collector.record(at: Date(timeIntervalSince1970: 2.0))
        collector.record(at: Date(timeIntervalSince1970: 3.0)) // segment B: [3000,4000]
        collector.record(at: Date(timeIntervalSince1970: 4.0))

        let segmentA = collector.flush(startMs: 1_000, endMs: 2_000)
        let segmentB = collector.flush(startMs: 3_000, endMs: 4_000)

        XCTAssertEqual(segmentA.sorted(), [1_000, 2_000])
        XCTAssertEqual(segmentB.sorted(), [3_000, 4_000])
    }

    func testRestoreReturnsTimestampsOnRetry() {
        let collector = UserActivityCollector()
        collector.record(at: Date(timeIntervalSince1970: 1.5)) // 1500 ms

        let flushed = collector.flush(startMs: 1_000, endMs: 2_000)
        XCTAssertEqual(flushed, [1_500])

        // Simulate failed send — restore timestamps
        collector.restore(flushed)

        let reflushed = collector.flush(startMs: 1_000, endMs: 2_000)
        XCTAssertEqual(reflushed, [1_500])
    }

    func testBufferCapDropsOldestEntries() {
        let collector = UserActivityCollector()
        // Record 10 001 timestamps: 0 ms … 10 000 ms
        for idx in 0 ..< 10_001 {
            collector.record(at: Date(timeIntervalSince1970: Double(idx)))
        }
        // Cap is 10 000 — oldest entry (0 ms, idx=0) must have been dropped
        let all = collector.flush(startMs: 0, endMs: 10_001_000)
        XCTAssertEqual(all.count, 10_000)
        // After drop, first retained timestamp is idx=1 → 1 000 ms
        XCTAssertEqual(all.min(), 1_000)
    }

    func testResetClearsBuffer() {
        let collector = UserActivityCollector()
        collector.record(at: Date(timeIntervalSince1970: 1.0))
        collector.reset()
        let flushed = collector.flush(startMs: 0, endMs: 100_000)
        XCTAssertTrue(flushed.isEmpty)
    }

    func testRecordingStopClearsBufferViaReset() {
        // After recording stops, timestamps accumulated before stop must not bleed
        // into the next recording session's segments.
        let collector = UserActivityCollector()
        collector.record(at: Date(timeIntervalSince1970: 1.0))
        collector.record(at: Date(timeIntervalSince1970: 2.0))

        // Simulate recording stop
        collector.reset()

        // Start recording again and add new activity
        collector.record(at: Date(timeIntervalSince1970: 10.0))

        let flushed = collector.flush(startMs: 0, endMs: 20_000)
        XCTAssertEqual(flushed, [10_000])
    }

    func testTimestampsFromBeforeResetDoNotAppearAfterRestart() {
        // Timestamps recorded before stop() must not appear in segments produced
        // after a subsequent start() — i.e. reset() truly clears the buffer.
        let collector = UserActivityCollector()
        collector.record(at: Date(timeIntervalSince1970: 1.0)) // 1 000 ms — pre-stop
        collector.reset()
        // No new activity after restart
        let flushed = collector.flush(startMs: 0, endMs: 100_000)
        XCTAssertTrue(flushed.isEmpty)
    }
}
