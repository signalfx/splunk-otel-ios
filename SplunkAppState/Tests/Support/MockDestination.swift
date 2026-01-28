//
/*
Copyright 2025 Splunk Inc.

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
@testable import SplunkAppState
@testable import SplunkCommon

final class MockDestination: AppStateDestination {

    private let lock = NSLock()

    // swiftlint:disable:next large_tuple
    private(set) var events: [(state: AppStateType, time: Date, shared: AgentSharedState?)] = []

    var onSend: (() -> Void)?

    func send(appState: AppStateType, time: Date, sharedState: AgentSharedState?) {
        lock.lock()
        events.append((appState, time, sharedState))
        let cb = onSend
        lock.unlock()
        cb?()
    }

    func reset() {
        lock.lock()
        events.removeAll()
        lock.unlock()
    }
}
