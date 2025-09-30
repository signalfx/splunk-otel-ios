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

    nonisolated func applicationState(for timestamp: Date) -> String? {
        return "testing-application-state"
    }
}

// MARK: - Mock LogAgent

/// A thread-safe mock implementation of `LogAgent` that captures log messages for verification in tests.
final class MockLogAgent: @unchecked Sendable, LogAgent {

    // MARK: - Inline types

    struct LogMessage {
        let level: LogLevel
        let message: String
    }

    // MARK: - Private

    private let lock = NSLock()
    private var _logMessages: [LogMessage] = []

    // MARK: - Public

    nonisolated let poolName: String
    nonisolated let category: String?

    var logMessages: [LogMessage] {
        lock.lock()
        defer { lock.unlock() }
        return _logMessages
    }

    // MARK: - Initialization

    init(poolName: String, category: String? = nil) {
        self.poolName = poolName
        self.category = category
    }

    convenience init() {
        self.init(poolName: "mock-pool", category: "mock-category")
    }

    // MARK: - LogAgent methods

    nonisolated func process(configuration _: CiscoLogger.ConfigurationMessage) {}

    func log(level: CiscoLogger.LogLevel, isPrivate _: Bool, message: @escaping @Sendable () -> String) {
        lock.lock()
        _logMessages.append(LogMessage(level: level, message: message()))
        lock.unlock()
    }
}
