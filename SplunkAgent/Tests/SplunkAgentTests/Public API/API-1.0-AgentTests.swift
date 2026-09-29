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

import OpenTelemetryApi
import XCTest

@testable import SplunkAgent
@testable import SplunkOpenTelemetry

final class API10AgentTests: XCTestCase {

    // MARK: - Private

    private var agent: SplunkRum?


    // MARK: - Tests lifecycle

    override func setUp() {
        super.setUp()

        agent = nil
    }

    override func tearDown() {
        agent = nil
        SplunkRum.resetSharedInstance()

        super.tearDown()
    }


    // MARK: - API Tests

    func testInstall_givenAgentNotSampledOut() throws {
        // Test initial state
        XCTAssertTrue(SplunkRum.shared.state.status == .notRunning(.notInstalled))

        // Agent initialization
        agent = try AgentTestBuilder.buildDefault()

        // Agent install
        let configuration = try ConfigurationTestBuilder.buildDefault()
        agent = try SplunkRum.install(with: configuration)

        // The agent should run after install
        let agentStatus = try XCTUnwrap(agent?.state.status)
        let expectedStatus = expectedAgentStatus()
        XCTAssertEqual(agentStatus, expectedStatus)

        // Check OpenTelemetry instance
        XCTAssertNotNil(agent?.openTelemetry)

        // Another attempt to install should return an instance from the previous attempt
        let anotherAgentInstance = try SplunkRum.install(with: configuration)
        XCTAssertTrue(agent === anotherAgentInstance)
    }

    func testInstall_givenAgentSampledOut() throws {
        // Test initial state
        XCTAssertTrue(SplunkRum.shared.state.status == .notRunning(.notInstalled))

        // Agent initialization
        agent = try AgentTestBuilder.buildDefault()

        // Agent install
        let configuration = try ConfigurationTestBuilder.buildDefaultSampledOut()
        agent = try SplunkRum.install(with: configuration)

        // The agent be sampled out after install
        let agentStatus = try XCTUnwrap(agent?.state.status)

        XCTAssertEqual(agentStatus, .notRunning(.sampledOut))

        // Check OpenTelemetry instance
        XCTAssertNotNil(agent?.openTelemetry)

        // Another attempt to install should return an instance from the previous attempt
        let anotherAgentInstance = try SplunkRum.install(with: configuration)
        XCTAssertTrue(agent === anotherAgentInstance)
    }

    func testInstall_recordsVersionBeforeSampling() throws {
        let storage = UserDefaultsStorage()
        try? storage.delete(forKey: AppInstallationStorage.installationIdKey)
        try? storage.delete(forKey: AppVersionTracker.storageKey)
        defer {
            try? storage.delete(forKey: AppInstallationStorage.installationIdKey)
            try? storage.delete(forKey: AppVersionTracker.storageKey)
        }

        var sampledOutConfiguration = try ConfigurationTestBuilder.buildDefaultSampledOut()
        sampledOutConfiguration.appVersion = "5.2.0"
        _ = try SplunkRum.install(with: sampledOutConfiguration)

        SplunkRum.resetSharedInstance()

        var sampledInConfiguration = try ConfigurationTestBuilder.buildDefault()
        sampledInConfiguration.appVersion = "5.3.0"
        let installedAgent = try SplunkRum.install(with: sampledInConfiguration)
        let eventManager = try XCTUnwrap(installedAgent.eventManager as? DefaultEventManager)
        let logEventProcessor = try XCTUnwrap(eventManager.logEventProcessor as? OTLPLogToSpanEventProcessor)
        let resource = try XCTUnwrap(logEventProcessor.resource)

        XCTAssertEqual(resource.attributes["app.version"], .string("5.3.0"))
        XCTAssertEqual(resource.attributes["app.previous_version"], .string("5.2.0"))
    }

    // MARK: - Private methods

    private func expectedAgentStatus() -> SplunkAgent.Status {
        let isSupportedPlatform = PlatformSupport.current.scope == .full

        return isSupportedPlatform ? .running : .notRunning(.unsupportedPlatform)
    }
}
