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
import SplunkCommon

/// An `AgentSharedState` whose session ID and metadata a test can change.
///
/// Safety: the module under test reads the state on the main thread while a test may change it, and `lock`
/// guards both stored values. A `Mutex` (iOS 18 and later) would remove the `@unchecked`.
final class MockAgentSharedState: AgentSharedState, @unchecked Sendable {

    // MARK: - Private

    private let lock = NSLock()
    private var sessionIdStorage: String
    private var sessionMetadataStorage: String?


    // MARK: - AgentSharedState

    var sessionId: String {
        lock.lock()
        defer { lock.unlock() }

        return sessionIdStorage
    }

    var sessionMetadata: String? {
        lock.lock()
        defer { lock.unlock() }

        return sessionMetadataStorage
    }

    let agentVersion = "test"

    func applicationState(for _: Date) -> String? {
        nil
    }


    // MARK: - Initialization

    init(sessionId: String, sessionMetadata: String? = nil) {
        sessionIdStorage = sessionId
        sessionMetadataStorage = sessionMetadata
    }


    // MARK: - Updates

    func updateSessionId(_ newId: String) {
        lock.lock()
        defer { lock.unlock() }

        sessionIdStorage = newId
    }
}
