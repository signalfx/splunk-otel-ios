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

import SplunkSessionReplayProxy
import XCTest

@testable import SplunkAgent

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

    func testDeferredEndpointSessionReplayStaysNonOperationalWhenDisabledByConfiguration() throws {
        let configuration = buildConfigurationWithoutEndpoint()
        let moduleConfigurations: [Any] = [
            SessionReplayConfiguration(enabled: false, samplingRate: 1.0),
        ]

        let installedAgent = try SplunkRum.install(
            with: configuration,
            moduleConfigurations: moduleConfigurations
        )

        XCTAssertTrue(installedAgent.sessionReplayProxy is SessionReplayNonOperational)

        let endpoint = EndpointConfiguration(
            realm: ConfigurationTestBuilder.realm,
            rumAccessToken: ConfigurationTestBuilder.rumAccessToken
        )
        try installedAgent.updateEndpoint(endpoint)

        XCTAssertTrue(installedAgent.sessionReplayProxy is SessionReplayNonOperational)
        XCTAssertEqual(installedAgent.sessionReplay.state.status, .notRecording(.notStarted))
    }

    func testDeferredEndpointSessionReplayStaysNonOperationalWhenSampledOut() throws {
        let configuration = buildConfigurationWithoutEndpoint()
        let moduleConfigurations: [Any] = [
            SessionReplayConfiguration(enabled: true, samplingRate: 0.0),
        ]

        let installedAgent = try SplunkRum.install(
            with: configuration,
            moduleConfigurations: moduleConfigurations
        )

        XCTAssertTrue(installedAgent.sessionReplayProxy is SessionReplayNonOperational)

        let endpoint = EndpointConfiguration(
            realm: ConfigurationTestBuilder.realm,
            rumAccessToken: ConfigurationTestBuilder.rumAccessToken
        )
        try installedAgent.updateEndpoint(endpoint)

        XCTAssertTrue(installedAgent.sessionReplayProxy is SessionReplayNonOperational)
        XCTAssertEqual(installedAgent.sessionReplay.state.status, .notRecording(.disabledBySampling))
    }

    func testDeferredEndpointSessionReplayBecomesOperationalWhenEnabledAndSampledIn() throws {
        let configuration = buildConfigurationWithoutEndpoint()
        let moduleConfigurations: [Any] = [
            SessionReplayConfiguration(enabled: true, samplingRate: 1.0),
        ]

        let installedAgent = try SplunkRum.install(
            with: configuration,
            moduleConfigurations: moduleConfigurations
        )

        XCTAssertTrue(installedAgent.sessionReplayProxy is SessionReplayNonOperational)

        let endpoint = EndpointConfiguration(
            realm: ConfigurationTestBuilder.realm,
            rumAccessToken: ConfigurationTestBuilder.rumAccessToken
        )
        try installedAgent.updateEndpoint(endpoint)

        XCTAssertTrue(installedAgent.sessionReplayProxy is SessionReplay)
    }

    func testDeferredEndpointSessionReplayDecisionIsNotReEvaluatedOnSubsequentUpdates() throws {
        let configuration = buildConfigurationWithoutEndpoint()
        let moduleConfigurations: [Any] = [
            SessionReplayConfiguration(enabled: true, samplingRate: 0.0),
        ]

        let installedAgent = try SplunkRum.install(
            with: configuration,
            moduleConfigurations: moduleConfigurations
        )

        let endpoint = EndpointConfiguration(
            realm: ConfigurationTestBuilder.realm,
            rumAccessToken: ConfigurationTestBuilder.rumAccessToken
        )
        try installedAgent.updateEndpoint(endpoint)

        XCTAssertTrue(installedAgent.sessionReplayProxy is SessionReplayNonOperational)
        XCTAssertEqual(installedAgent.sessionReplay.state.status, .notRecording(.disabledBySampling))

        // A second endpoint update must not re-evaluate the sampling decision
        let secondEndpoint = EndpointConfiguration(
            realm: "us1",
            rumAccessToken: ConfigurationTestBuilder.rumAccessToken
        )
        try installedAgent.updateEndpoint(secondEndpoint)

        XCTAssertTrue(installedAgent.sessionReplayProxy is SessionReplayNonOperational)
        XCTAssertEqual(installedAgent.sessionReplay.state.status, .notRecording(.disabledBySampling))
    }

    func testDeferredEndpointWithoutReplayUrlDoesNotPreventLaterEvaluation() throws {
        let configuration = buildConfigurationWithoutEndpoint()
        let moduleConfigurations: [Any] = [
            SessionReplayConfiguration(enabled: true, samplingRate: 1.0),
        ]

        let installedAgent = try SplunkRum.install(
            with: configuration,
            moduleConfigurations: moduleConfigurations
        )

        // First endpoint has trace only — no session replay URL
        let traceUrl = try ConfigurationTestBuilder.customUrl(for: ConfigurationTestBuilder.customTraceAddress)
        let traceOnlyEndpoint = EndpointConfiguration(trace: traceUrl)
        try installedAgent.updateEndpoint(traceOnlyEndpoint)

        // Decision should NOT have been made yet (no replay URL to trigger it)
        XCTAssertFalse(installedAgent.sessionReplayDecisionMade)
        XCTAssertTrue(installedAgent.sessionReplayProxy is SessionReplayNonOperational)

        // Second endpoint includes a session replay URL — should now evaluate
        let fullEndpoint = EndpointConfiguration(
            realm: ConfigurationTestBuilder.realm,
            rumAccessToken: ConfigurationTestBuilder.rumAccessToken
        )
        try installedAgent.updateEndpoint(fullEndpoint)

        XCTAssertTrue(installedAgent.sessionReplayDecisionMade)
        XCTAssertTrue(installedAgent.sessionReplayProxy is SessionReplay)
    }

    // MARK: - Private methods

    private func buildConfigurationWithoutEndpoint() -> AgentConfiguration {
        var configuration = AgentConfiguration(
            endpoint: nil,
            appName: ConfigurationTestBuilder.appName,
            deploymentEnvironment: ConfigurationTestBuilder.deploymentEnvironment
        )

        configuration.appVersion = ConfigurationTestBuilder.appVersion
        configuration.enableDebugLogging = true
        configuration.globalAttributes = MutableAttributes(dictionary: ["attribute": .string("value")])

        return configuration
    }

    private func expectedAgentStatus() -> Status {
        let isSupportedPlatform = PlatformSupport.current.scope == .full

        return isSupportedPlatform ? .running : .notRunning(.unsupportedPlatform)
    }
}
