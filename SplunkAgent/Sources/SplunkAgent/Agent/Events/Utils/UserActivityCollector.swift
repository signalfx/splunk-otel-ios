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
actor UserActivityCollector {

    // MARK: - Private properties

    private var timestamps: [Int] = []


    // MARK: - Interface

    /// Records a user interaction at the given time.
    func record(at date: Date) {
        let ms = Int(date.timeIntervalSince1970 * 1_000.0)
        timestamps.append(ms)
    }

    /// Returns timestamps that fall within [startMs, endMs] and removes them from the internal buffer. Timestamps after endMs are retained for the next segment.
    func flush(startMs: Int, endMs: Int) -> [Int] {
        let collected = timestamps.filter { $0 >= startMs && $0 <= endMs }
        timestamps = timestamps.filter { $0 > endMs }
        return collected
    }
}
