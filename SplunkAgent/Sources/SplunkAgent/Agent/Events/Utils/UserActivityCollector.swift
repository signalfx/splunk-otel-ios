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

/// Collects user interaction timestamps for inclusion in session replay metadata.
///
/// Timestamps are stored as Unix milliseconds and flushed when a session replay segment is produced.
/// Delivery is best-effort: the buffer is capped at `maxBufferSize` and the oldest entries
/// are dropped when the cap is exceeded.
actor UserActivityCollector {

    // MARK: - Private properties

    private var timestamps: [Int] = []

    private static let maxBufferSize = 10_000


    // MARK: - Interface

    /// Records a user interaction at the given time.
    func record(at date: Date) {
        let ms = Int(date.timeIntervalSince1970 * 1_000.0)
        timestamps.append(ms)
        if timestamps.count > Self.maxBufferSize {
            timestamps.removeFirst(timestamps.count - Self.maxBufferSize)
        }
    }

    /// Returns timestamps that fall within [startMs, endMs] and removes exactly those timestamps from the buffer.
    ///
    /// Only timestamps in the given window are removed; timestamps outside the window
    /// (both before startMs and after endMs) are retained for other segment flushes.
    func flush(startMs: Int, endMs: Int) -> [Int] {
        let collected = timestamps.filter { $0 >= startMs && $0 <= endMs }
        timestamps = timestamps.filter { $0 < startMs || $0 > endMs }
        return collected
    }

    /// Re-inserts timestamps that were previously flushed but whose segment failed to send.
    ///
    /// Called on the retry path so that the activity data is not silently lost.
    func restore(_ restored: [Int]) {
        timestamps.append(contentsOf: restored)
        timestamps.sort()
        if timestamps.count > Self.maxBufferSize {
            timestamps.removeFirst(timestamps.count - Self.maxBufferSize)
        }
    }

    /// Clears all buffered timestamps.
    ///
    /// Call when session replay recording stops or resets.
    func reset() {
        timestamps.removeAll()
    }
}
