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
@testable import SplunkCommon
internal import CiscoLogger
@testable import SplunkWebView

/// A thread-safe mock implementation of `AgentSharedState` for testing purposes.
final class MockAgentSharedState: @unchecked Sendable, AgentSharedState {

    // MARK: - Private

    private let lock = NSLock()
    private var _sessionId: String

    // MARK: - Public

    nonisolated var sessionId: String {
        lock.lock()
        defer { lock.unlock() }
        return _sessionId
    }

    nonisolated let agentVersion: String = "testing-agent-version"

    // MARK: - Initialization

    init(sessionId: String) {
        _sessionId = sessionId
    }

    // MARK: - Public Methods

    func updateSessionId(_ newId: String) {
        lock.lock()
        _sessionId = newId
        lock.unlock()
    }

    nonisolated func applicationState(for _: Date) -> String? {
        "testing-application-state"
    }
}
