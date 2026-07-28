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

    func testFlushReturnsOnlyTimestampsInsideWindow() {
        let collector = makeRecordingCollector()
        collector.record(at: Date(timeIntervalSince1970: 1.0)) // 1000 ms
        collector.record(at: Date(timeIntervalSince1970: 2.0)) // 2000 ms
        collector.record(at: Date(timeIntervalSince1970: 3.0)) // 3000 ms

        let flushed = collector.flush(startMs: 1_500, endMs: 2_500)

        // Only 2000 ms is inside [1500, 2500]. 1000 ms and 3000 ms are
        // retained for whichever segment actually owns their window.
        XCTAssertEqual(flushed.timestamps.sorted(), [2_000])
    }

    func testFlushRetainsTimestampsOutsideWindow() {
        let collector = makeRecordingCollector()
        collector.record(at: Date(timeIntervalSince1970: 1.0))
        collector.record(at: Date(timeIntervalSince1970: 2.0))
        collector.record(at: Date(timeIntervalSince1970: 3.0))

        _ = collector.flush(startMs: 1_500, endMs: 2_500)

        // Both 1000 (before window) and 3000 (after window) must survive the
        // first flush and become available to a subsequent wider window.
        let remaining = collector.flush(startMs: 500, endMs: 4_000)

        XCTAssertEqual(remaining.timestamps.sorted(), [1_000, 3_000])
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

    func testSegmentBFlushedBeforeSegmentAStillPreservesOwnership() {
        // Two segments run concurrently. Segment B finishes preparing first
        // and calls `flush` before segment A. Segment A must still receive
        // its own activity — B cannot consume it, even though B ran first.
        let collector = makeRecordingCollector()
        collector.record(at: Date(timeIntervalSince1970: 1.0)) // owned by A
        collector.record(at: Date(timeIntervalSince1970: 2.0)) // owned by A
        collector.record(at: Date(timeIntervalSince1970: 3.0)) // owned by B
        collector.record(at: Date(timeIntervalSince1970: 4.0)) // owned by B

        let segmentB = collector.flush(startMs: 3_000, endMs: 4_000)
        let segmentA = collector.flush(startMs: 1_000, endMs: 2_000)

        XCTAssertEqual(segmentB.timestamps.sorted(), [3_000, 4_000])
        XCTAssertEqual(segmentA.timestamps.sorted(), [1_000, 2_000])
    }

    func testEventOutsideAnyKnownWindowIsRetainedNotOrphaned() {
        // Events that do not fit any active segment window remain in the
        // buffer until a matching (or wider) window flushes them, so a
        // future retry or wider window can still recover them.
        let collector = makeRecordingCollector()
        collector.record(at: Date(timeIntervalSince1970: 1.5)) // 1500 ms

        // A neighbouring segment [2000, 3000] must not consume it.
        let neighbour = collector.flush(startMs: 2_000, endMs: 3_000)
        XCTAssertTrue(neighbour.timestamps.isEmpty)

        // A subsequent wider window that actually covers it still can.
        let recovery = collector.flush(startMs: 0, endMs: 3_000)
        XCTAssertEqual(recovery.timestamps, [1_500])
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

    func testFailedSegmentAActivityIsNotConsumedBySegmentB() {
        // Segment A publishes and fails. Its activity is restored to the
        // collector. Segment B then runs its own flush — because B filters
        // strictly by its own window, it must not steal A's timestamps, and
        // A's restored activity remains available for A's retry.
        let collector = makeRecordingCollector()
        collector.record(at: Date(timeIntervalSince1970: 1.0))
        collector.record(at: Date(timeIntervalSince1970: 2.0)) // both belong to A
        collector.record(at: Date(timeIntervalSince1970: 3.0))
        collector.record(at: Date(timeIntervalSince1970: 4.0)) // both belong to B

        // A flushes, publish fails, activity is restored.
        let segmentA = collector.flush(startMs: 1_000, endMs: 2_000)
        collector.restore(segmentA.timestamps, generation: segmentA.generation)

        // B flushes its own window while A's retry hasn't happened yet.
        let segmentB = collector.flush(startMs: 3_000, endMs: 4_000)
        XCTAssertEqual(segmentB.timestamps.sorted(), [3_000, 4_000])

        // A's timestamps are still recoverable for its retry.
        let retryA = collector.flush(startMs: 1_000, endMs: 2_000)
        XCTAssertEqual(retryA.timestamps.sorted(), [1_000, 2_000])
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
