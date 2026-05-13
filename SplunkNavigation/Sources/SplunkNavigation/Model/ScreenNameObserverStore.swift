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

/// Lock-protected holder for the agent's synchronous screen-name observer.
final class ScreenNameObserverStore: @unchecked Sendable {

    // MARK: - Private

    private let lock = NSLock()
    private var observer: (@Sendable (String) -> Void)?


    // MARK: - Observer

    func set(_ observer: (@Sendable (String) -> Void)?) {
        lock.withLock { self.observer = observer }
    }

    func publish(_ name: String) {
        lock.withLock { observer }?(name)
    }
}
