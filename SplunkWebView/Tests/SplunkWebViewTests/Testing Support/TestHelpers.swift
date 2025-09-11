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

// MARK: - Mock AgentSharedState

final class MockAgentSharedState: @unchecked Sendable, AgentSharedState {
    private let lock = NSLock()

    private var _sessionId: String
    nonisolated var sessionId: String {
        lock.lock()
        defer { lock.unlock() }
        return _sessionId
    }

    nonisolated let agentVersion: String = "testing-agent-version"

    init(sessionId: String) {
        _sessionId = sessionId
    }

    func updateSessionId(_ newId: String) {
        lock.lock()
        _sessionId = newId
        lock.unlock()
    }

    nonisolated func applicationState(for timestamp: Date) -> String? {
        return "testing-application-state"
    }
}

// MARK: - Mock LogAgent

final class MockLogAgent: @unchecked Sendable, LogAgent {
    struct LogMessage {
        let level: LogLevel
        let message: String
    }

    private let lock = NSLock()

    nonisolated let poolName: String
    nonisolated let category: String?

    private var _logMessages: [LogMessage] = []
    var logMessages: [LogMessage] {
        lock.lock()
        defer { lock.unlock() }
        return _logMessages
    }

    init(poolName: String, category: String? = nil) {
        self.poolName = poolName
        self.category = category
    }

    convenience init() {
        self.init(poolName: "mock-pool", category: "mock-category")
    }

    nonisolated func process(configuration: CiscoLogger.ConfigurationMessage) {
        // No-op for testing
    }

    func log(level: CiscoLogger.LogLevel, isPrivate: Bool, message: @escaping @Sendable () -> String) {
        lock.lock()
        _logMessages.append(LogMessage(level: level, message: message()))
        lock.unlock()
    }
}
