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
import OpenTelemetrySdk

/// Records the names of the spans it is given, from any thread.
///
/// It can also run an action once a span with a given name arrives, so a test can wait for that span.
///
/// Safety: spans arrive on export threads while the test reads the names, and `lock` guards all stored
/// state. A `Mutex` (iOS 18 and later) would remove the `@unchecked`.
final class SpanNameRecorder: @unchecked Sendable {

    // MARK: - Private

    private let lock = NSLock()
    private var recordedNames: [String] = []
    private var watchedName: String?
    private var onWatchedName: (@Sendable () -> Void)?


    // MARK: - Public

    var names: [String] {
        lock.lock()
        defer { lock.unlock() }

        return recordedNames
    }

    /// Runs `action` when a span named `name` is recorded.
    func onName(_ name: String, perform action: @escaping @Sendable () -> Void) {
        lock.lock()
        defer { lock.unlock() }

        watchedName = name
        onWatchedName = action
    }

    func record(_ spans: [SpanData]) {
        lock.lock()
        recordedNames.append(contentsOf: spans.map(\.name))
        let action = spans.contains { $0.name == watchedName } ? onWatchedName : nil
        lock.unlock()

        action?()
    }
}
