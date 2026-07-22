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

    // MARK: - Helpers

    /// Returns a collector primed as-if Session Replay had started recording.
    private func makeRecordingCollector() -> UserActivityCollector {
        let collector = UserActivityCollector()
        collector.setRecording(true)
        return collector
    }


    // MARK: - Basic flush semantics

    func testFlushReturnsOnlyTimestampsUpToEndOfWindow() {
        let collector = makeRecordingCollector()
        collector.record(at: Date(timeIntervalSince1970: 1.0)) // 1000 ms
        collector.record(at: Date(timeIntervalSince1970: 2.0)) // 2000 ms
        collector.record(at: Date(timeIntervalSince1970: 3.0)) // 3000 ms

        let flushed = collector.flush(startMs: 1_500, endMs: 2_500)

        // 1000 ms belongs to a past window that was never flushed — it
        // rides along with the current segment so it isn't orphaned.
        XCTAssertEqual(flushed.timestamps.sorted(), [1_000, 2_000])
    }

    func testFlushRetainsTimestampsAfterEndOfWindow() {
        let collector = makeRecordingCollector()
        collector.record(at: Date(timeIntervalSince1970: 1.0))
        collector.record(at: Date(timeIntervalSince1970: 2.0))
        collector.record(at: Date(timeIntervalSince1970: 3.0))

        _ = collector.flush(startMs: 1_500, endMs: 2_500)
        let remaining = collector.flush(startMs: 500, endMs: 4_000)

        XCTAssertEqual(remaining.timestamps.sorted(), [3_000])
    }

    func testSequentialFlushesDoNotStealEachOthersTimestamps() {
        let collector = makeRecordingCollector()
        collector.record(at: Date(timeIntervalSince1970: 1.0)) // segment A
        collector.record(at: Date(timeIntervalSince1970: 2.0))
        collector.record(at: Date(timeIntervalSince1970: 3.0)) // segment B
        collector.record(at: Date(timeIntervalSince1970: 4.0))

        let segmentA = collector.flush(startMs: 1_000, endMs: 2_000)
        let segmentB = collector.flush(startMs: 3_000, endMs: 4_000)

        XCTAssertEqual(segmentA.timestamps.sorted(), [1_000, 2_000])
        XCTAssertEqual(segmentB.timestamps.sorted(), [3_000, 4_000])
    }

    func testLateArrivingEventJoinsNextSegment() {
        // A tap that fires just after segment A's endMs but arrives after
        // segment B has been prepared must still be delivered on segment C —
        // it must never be silently dropped.
        let collector = makeRecordingCollector()

        // Segment A covers [1000, 2000]; nothing happened during it.
        let segmentA = collector.flush(startMs: 1_000, endMs: 2_000)
        XCTAssertTrue(segmentA.timestamps.isEmpty)

        // Late-arriving event whose real timestamp was inside segment A.
        // Use a millisecond value that is exactly representable in Double so
        // the collector's floor-to-ms conversion returns exactly 1500.
        collector.record(at: Date(timeIntervalSince1970: 1.5)) // 1500 ms

        // Segment B [2000, 3000] — the late event fits <=endMs and rides.
        let segmentB = collector.flush(startMs: 2_000, endMs: 3_000)
        XCTAssertEqual(segmentB.timestamps, [1_500])
    }


    // MARK: - Recording gate

    func testRecordIgnoredWhenNotRecording() {
        let collector = UserActivityCollector() // starts stopped by default
        collector.record(at: Date(timeIntervalSince1970: 1.0))

        let flushed = collector.flush(startMs: 0, endMs: 100_000)
        XCTAssertTrue(flushed.timestamps.isEmpty)
    }

    func testSetRecordingFalseStopsFurtherCollection() {
        let collector = makeRecordingCollector()
        collector.record(at: Date(timeIntervalSince1970: 1.0))
        collector.setRecording(false)
        collector.record(at: Date(timeIntervalSince1970: 2.0))

        let flushed = collector.flush(startMs: 0, endMs: 100_000)
        XCTAssertEqual(flushed.timestamps, [1_000])
    }


    // MARK: - Retry / restore

    func testRestoreOnMatchingGenerationReturnsTimestamps() {
        let collector = makeRecordingCollector()
        collector.record(at: Date(timeIntervalSince1970: 1.5))

        let flushed = collector.flush(startMs: 1_000, endMs: 2_000)
        XCTAssertEqual(flushed.timestamps, [1_500])

        collector.restore(flushed.timestamps, generation: flushed.generation)

        let reflushed = collector.flush(startMs: 1_000, endMs: 2_000)
        XCTAssertEqual(reflushed.timestamps, [1_500])
    }

    func testRestoreAfterResetIsDropped() {
        // A failure callback that fires after stop/reset must not smuggle the
        // previous recording's activity into a new recording session.
        let collector = makeRecordingCollector()
        collector.record(at: Date(timeIntervalSince1970: 1.5))
        let flushed = collector.flush(startMs: 1_000, endMs: 2_000)

        collector.reset()
        collector.setRecording(true)
        collector.record(at: Date(timeIntervalSince1970: 10.0))

        // Restore with the stale generation from before reset.
        collector.restore(flushed.timestamps, generation: flushed.generation)

        let after = collector.flush(startMs: 0, endMs: 100_000)
        XCTAssertEqual(after.timestamps, [10_000])
    }


    // MARK: - Buffer cap

    func testBufferCapAmortizedTrim() {
        let collector = makeRecordingCollector()
        // Overshoot the cap by more than trimSlack to force at least one trim.
        for idx in 0 ..< 12_000 {
            collector.record(at: Date(timeIntervalSince1970: Double(idx)))
        }

        let flushed = collector.flush(startMs: 0, endMs: 12_001_000)
        XCTAssertLessThanOrEqual(flushed.timestamps.count, 10_000 + 1_024)
        XCTAssertGreaterThanOrEqual(flushed.timestamps.count, 10_000)
    }


    // MARK: - Reset

    func testResetClearsBufferAndInvalidatesOutstandingFlushes() {
        let collector = makeRecordingCollector()
        collector.record(at: Date(timeIntervalSince1970: 1.0))
        collector.reset()

        let flushed = collector.flush(startMs: 0, endMs: 100_000)
        XCTAssertTrue(flushed.timestamps.isEmpty)
    }
}
