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
/// Timestamps are stored as Unix milliseconds and flushed when a session replay
/// segment is produced. The collector is gated by an explicit recording flag — no
/// timestamps are accepted while recording is stopped, so an idle host app cannot
/// accumulate unbounded state through the `onActivity` callback.
///
/// Delivery is best-effort: when the buffer exceeds `maxBufferSize`, the oldest
/// entries are dropped in batches so amortized `record(at:)` cost stays O(1) at
/// the cap. Timestamps that arrive late (i.e. after the segment they belonged to
/// was already published) are attached to the next segment rather than orphaned.
///
/// Thread-safe: all methods may be called from any thread or actor context.
final class UserActivityCollector {

    // MARK: - Private properties

    private var timestamps: [Int] = []

    /// Whether the collector currently accepts events.
    ///
    /// Defaults to `false` — the collector only accepts events once Session
    /// Replay explicitly enters the recording state via `setRecording(true)`.
    /// This prevents activity from accumulating for an app that never starts
    /// Session Replay (e.g. sampled-out or not installed).
    private var isRecording: Bool = false

    /// Generation counter incremented on every `reset()`.
    ///
    /// The counter is returned with each `flush()` and required by `restore()`
    /// so a failure callback that arrives after a subsequent stop/reset cannot
    /// leak stale timestamps into the new recording session.
    private var generation: UInt64 = 0

    private let lock = NSLock()

    private static let maxBufferSize = 10_000

    /// Trim slack for the buffer cap.
    ///
    /// When the buffer exceeds `maxBufferSize + trimSlack`, the oldest
    /// `trimSlack` items are dropped in a single `removeFirst(_:)`. This keeps
    /// `record(at:)` amortized O(1) instead of shifting ~10 000 elements on
    /// every event once the cap is reached.
    private static let trimSlack = 1_024


    // MARK: - Interface

    /// Records a user interaction at the given time.
    ///
    /// No-op when recording is stopped, so the buffer cannot grow while the host
    /// app is idle or when `Interactions` is instrumented but Session Replay is
    /// not consuming activity.
    func record(at date: Date) {
        let ms = Int(date.timeIntervalSince1970 * 1_000.0)

        lock.withLock {
            guard isRecording else {
                return
            }

            timestamps.append(ms)

            if timestamps.count > Self.maxBufferSize + Self.trimSlack {
                timestamps.removeFirst(timestamps.count - Self.maxBufferSize)
            }
        }
    }

    /// Returns timestamps that fall within `[startMs, endMs]` along with the
    /// generation token needed to restore them on failure.
    ///
    /// Filtering is strict on both bounds so concurrent segment tasks cannot
    /// steal each other's activity — a segment always receives exactly the
    /// events that occurred inside its own window. Timestamps outside the
    /// window (before `startMs` or after `endMs`) are retained so they can be
    /// picked up by the segment that actually owns them, regardless of the
    /// order in which segments finish publishing.
    func flush(startMs: Int, endMs: Int) -> (timestamps: [Int], generation: UInt64) {
        lock.withLock {
            let collected = timestamps.filter {
                $0 >= startMs && $0 <= endMs
            }
            timestamps = timestamps.filter {
                $0 < startMs || $0 > endMs
            }

            return (collected, generation)
        }
    }

    /// Re-inserts timestamps that were previously flushed but whose segment
    /// failed to send.
    ///
    /// The `generation` token must match the collector's current generation.
    /// If a stop/reset happened after `flush()` returned these timestamps, the
    /// call is dropped — otherwise a delayed failure callback would leak the
    /// previous recording's activity into a new session.
    func restore(_ restored: [Int], generation: UInt64) {
        guard !restored.isEmpty else {
            return
        }

        lock.withLock {
            guard generation == self.generation else {
                return
            }

            timestamps.append(contentsOf: restored)
            timestamps.sort()

            if timestamps.count > Self.maxBufferSize {
                timestamps.removeFirst(timestamps.count - Self.maxBufferSize)
            }
        }
    }

    /// Enables or disables timestamp collection.
    ///
    /// When Session Replay stops recording, call `setRecording(false)` so
    /// interaction events raised while stopped do not accumulate. Call
    /// `setRecording(true)` again when a new recording session begins.
    func setRecording(_ recording: Bool) {
        lock.withLock {
            isRecording = recording
        }
    }

    /// Clears buffered timestamps and invalidates any outstanding flush
    /// generations so a late failure-callback restore is discarded.
    ///
    /// Prefer calling at the start of a new recording session rather than at
    /// stop time — resetting during `stop()` would race with the last
    /// segment's asynchronous publish and drop its activity.
    func reset() {
        lock.withLock {
            timestamps.removeAll()
            generation &+= 1
        }
    }
}
