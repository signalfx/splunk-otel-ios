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
        collector.record(at: Date(timeIntervalSince1970: 1.0))   // 1000 ms
        collector.record(at: Date(timeIntervalSince1970: 2.0))   // 2000 ms
        collector.record(at: Date(timeIntervalSince1970: 3.0))   // 3000 ms

        let flushed = collector.flush(startMs: 1500, endMs: 2500)

        XCTAssertEqual(flushed, [2000])
    }

    func testFlushDoesNotRemoveTimestampsOutsideWindow() {
        let collector = UserActivityCollector()
        collector.record(at: Date(timeIntervalSince1970: 1.0))
        collector.record(at: Date(timeIntervalSince1970: 2.0))
        collector.record(at: Date(timeIntervalSince1970: 3.0))

        _ = collector.flush(startMs: 1500, endMs: 2500)
        let remaining = collector.flush(startMs: 500, endMs: 4000)

        XCTAssertEqual(remaining.sorted(), [1000, 3000])
    }

    func testConcurrentFlushesDoNotStealEachOthersTimestamps() {
        let collector = UserActivityCollector()
        collector.record(at: Date(timeIntervalSince1970: 1.0))  // segment A: [1000,2000]
        collector.record(at: Date(timeIntervalSince1970: 2.0))
        collector.record(at: Date(timeIntervalSince1970: 3.0))  // segment B: [3000,4000]
        collector.record(at: Date(timeIntervalSince1970: 4.0))

        let segmentA = collector.flush(startMs: 1000, endMs: 2000)
        let segmentB = collector.flush(startMs: 3000, endMs: 4000)

        XCTAssertEqual(segmentA.sorted(), [1000, 2000])
        XCTAssertEqual(segmentB.sorted(), [3000, 4000])
    }

    func testRestoreReturnsTimestampsOnRetry() {
        let collector = UserActivityCollector()
        collector.record(at: Date(timeIntervalSince1970: 1.5))  // 1500 ms

        let flushed = collector.flush(startMs: 1000, endMs: 2000)
        XCTAssertEqual(flushed, [1500])

        // Simulate failed send — restore timestamps
        collector.restore(flushed)

        let reflushed = collector.flush(startMs: 1000, endMs: 2000)
        XCTAssertEqual(reflushed, [1500])
    }

    func testBufferCapDropsOldestEntries() {
        let collector = UserActivityCollector()
        // Record 10 001 timestamps: 0 ms … 10 000 ms
        for i in 0 ..< 10_001 {
            collector.record(at: Date(timeIntervalSince1970: Double(i)))
        }
        // Cap is 10 000 — oldest entry (0 ms, i=0) must have been dropped
        let all = collector.flush(startMs: 0, endMs: 10_001_000)
        XCTAssertEqual(all.count, 10_000)
        // After drop, first retained timestamp is i=1 → 1 000 ms
        XCTAssertEqual(all.min(), 1_000)
    }

    func testResetClearsBuffer() {
        let collector = UserActivityCollector()
        collector.record(at: Date(timeIntervalSince1970: 1.0))
        collector.reset()
        let flushed = collector.flush(startMs: 0, endMs: 100_000)
        XCTAssertTrue(flushed.isEmpty)
    }
}
