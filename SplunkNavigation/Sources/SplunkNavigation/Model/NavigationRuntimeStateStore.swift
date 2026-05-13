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

/// Synchronous, lock-protected store for navigation state that must be readable
/// without an actor hop.
///
/// `moduleEnabled` and `screenName` are kept here so that `track(screen:attributes:)`
/// can check enabled state, swap the screen name, and emit — all synchronously on the
/// caller's thread, matching Android's `@Synchronized` setter pattern.
final class NavigationRuntimeStateStore: @unchecked Sendable {

    // MARK: - Private

    private let lock = NSLock()
    private var storedModuleEnabled: Bool = true
    private var storedScreenName: String = "unknown"


    // MARK: - Module enabled

    var moduleEnabled: Bool {
        lock.withLock { storedModuleEnabled }
    }

    func setModuleEnabled(_ enabled: Bool) {
        lock.withLock { storedModuleEnabled = enabled }
    }


    // MARK: - Screen name

    var screenName: String {
        lock.withLock { storedScreenName }
    }

    /// Atomically replaces the stored screen name and returns the previous value.
    @discardableResult
    func swapScreenName(_ name: String) -> String {
        lock.withLock {
            let previous = storedScreenName
            storedScreenName = name
            return previous
        }
    }
}
