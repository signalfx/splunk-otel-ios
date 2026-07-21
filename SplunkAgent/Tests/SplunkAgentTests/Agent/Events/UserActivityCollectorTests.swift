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

    func testFlushReturnsOnlyWindowTimestamps() async {
        let collector = UserActivityCollector()
        await collector.record(at: Date(timeIntervalSince1970: 1.0))   // 1000 ms
        await collector.record(at: Date(timeIntervalSince1970: 2.0))   // 2000 ms
        await collector.record(at: Date(timeIntervalSince1970: 3.0))   // 3000 ms

        let flushed = await collector.flush(startMs: 1500, endMs: 2500)

        XCTAssertEqual(flushed, [2000])
    }

    func testFlushDoesNotRemoveTimestampsOutsideWindow() async {
        let collector = UserActivityCollector()
        await collector.record(at: Date(timeIntervalSince1970: 1.0))
        await collector.record(at: Date(timeIntervalSince1970: 2.0))
        await collector.record(at: Date(timeIntervalSince1970: 3.0))

        _ = await collector.flush(startMs: 1500, endMs: 2500)
        let remaining = await collector.flush(startMs: 500, endMs: 4000)

        XCTAssertEqual(remaining.sorted(), [1000, 3000])
    }

    func testConcurrentFlushesDoNotStealEachOthersTimestamps() async {
        let collector = UserActivityCollector()
        await collector.record(at: Date(timeIntervalSince1970: 1.0))  // segment A: [1000,2000]
        await collector.record(at: Date(timeIntervalSince1970: 2.0))
        await collector.record(at: Date(timeIntervalSince1970: 3.0))  // segment B: [3000,4000]
        await collector.record(at: Date(timeIntervalSince1970: 4.0))

        let segmentA = await collector.flush(startMs: 1000, endMs: 2000)
        let segmentB = await collector.flush(startMs: 3000, endMs: 4000)

        XCTAssertEqual(segmentA.sorted(), [1000, 2000])
        XCTAssertEqual(segmentB.sorted(), [3000, 4000])
    }

    func testRestoreReturnsTimestampsOnRetry() async {
        let collector = UserActivityCollector()
        await collector.record(at: Date(timeIntervalSince1970: 1.5))  // 1500 ms

        let flushed = await collector.flush(startMs: 1000, endMs: 2000)
        XCTAssertEqual(flushed, [1500])

        // Simulate failed send — restore timestamps
        await collector.restore(flushed)

        let reflushed = await collector.flush(startMs: 1000, endMs: 2000)
        XCTAssertEqual(reflushed, [1500])
    }

    func testBufferCapDropsOldestEntries() async {
        let collector = UserActivityCollector()
        for i in 0 ..< 10_001 {
            await collector.record(at: Date(timeIntervalSince1970: Double(i)))
        }
        let all = await collector.flush(startMs: 0, endMs: 10_001_000)
        XCTAssertEqual(all.count, 10_000)
        XCTAssertEqual(all.first, 1000, "Oldest entry (0 ms) should have been dropped")
    }

    func testResetClearsBuffer() async {
        let collector = UserActivityCollector()
        await collector.record(at: Date(timeIntervalSince1970: 1.0))
        await collector.reset()
        let flushed = await collector.flush(startMs: 0, endMs: 100_000)
        XCTAssertTrue(flushed.isEmpty)
    }
}
