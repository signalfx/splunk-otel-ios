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

import SplunkNetwork
import SplunkSessionReplayProxy
import XCTest

@testable import SplunkAgent

final class API10DeferredEndpointTests: XCTestCase {

    // MARK: - Tests lifecycle

    override func setUp() {
        super.setUp()

        SplunkRum.resetSharedInstance()
    }

    override func tearDown() {
        SplunkRum.resetSharedInstance()

        super.tearDown()
    }


    // MARK: - Session Replay with Deferred Endpoint

    func testSessionReplayOperationalAtInstallEvenWithoutEndpoint() throws {
        let configuration = buildConfigurationWithoutEndpoint()
        let moduleConfigurations: [Any] = [
            SessionReplayConfiguration(enabled: true, samplingRate: 1.0)
        ]

        let installedAgent = try SplunkRum.install(
            with: configuration,
            moduleConfigurations: moduleConfigurations
        )

        XCTAssertTrue(
            installedAgent.sessionReplayProxy is SessionReplay,
            "Proxy should be operational at install even without an endpoint"
        )
        XCTAssertTrue(installedAgent.sessionReplayDecisionMade)
    }

    func testSessionReplayNonOperationalWhenDisabledByConfiguration() throws {
        let configuration = buildConfigurationWithoutEndpoint()
        let moduleConfigurations: [Any] = [
            SessionReplayConfiguration(enabled: false, samplingRate: 1.0)
        ]

        let installedAgent = try SplunkRum.install(
            with: configuration,
            moduleConfigurations: moduleConfigurations
        )

        XCTAssertTrue(installedAgent.sessionReplayProxy is SessionReplayNonOperational)
        XCTAssertEqual(installedAgent.sessionReplay.state.status, .notRecording(.notStarted))

        let endpoint = EndpointConfiguration(
            realm: ConfigurationTestBuilder.realm,
            rumAccessToken: ConfigurationTestBuilder.rumAccessToken
        )
        try installedAgent.updateEndpoint(endpoint)

        XCTAssertTrue(
            installedAgent.sessionReplayProxy is SessionReplayNonOperational,
            "Endpoint update must not re-evaluate a disabled configuration"
        )
    }

    func testSessionReplayNonOperationalWhenSampledOut() throws {
        let configuration = buildConfigurationWithoutEndpoint()
        let moduleConfigurations: [Any] = [
            SessionReplayConfiguration(enabled: true, samplingRate: 0.0)
        ]

        let installedAgent = try SplunkRum.install(
            with: configuration,
            moduleConfigurations: moduleConfigurations
        )

        XCTAssertTrue(installedAgent.sessionReplayProxy is SessionReplayNonOperational)
        XCTAssertEqual(installedAgent.sessionReplay.state.status, .notRecording(.disabledBySampling))

        let endpoint = EndpointConfiguration(
            realm: ConfigurationTestBuilder.realm,
            rumAccessToken: ConfigurationTestBuilder.rumAccessToken
        )
        try installedAgent.updateEndpoint(endpoint)

        XCTAssertTrue(
            installedAgent.sessionReplayProxy is SessionReplayNonOperational,
            "Endpoint update must not re-evaluate a sampled-out decision"
        )
    }

    func testSessionReplayRemainsOperationalAfterEndpointUpdate() throws {
        let configuration = buildConfigurationWithoutEndpoint()
        let moduleConfigurations: [Any] = [
            SessionReplayConfiguration(enabled: true, samplingRate: 1.0)
        ]

        let installedAgent = try SplunkRum.install(
            with: configuration,
            moduleConfigurations: moduleConfigurations
        )

        XCTAssertTrue(installedAgent.sessionReplayProxy is SessionReplay)

        let endpoint = EndpointConfiguration(
            realm: ConfigurationTestBuilder.realm,
            rumAccessToken: ConfigurationTestBuilder.rumAccessToken
        )
        try installedAgent.updateEndpoint(endpoint)

        XCTAssertTrue(
            installedAgent.sessionReplayProxy is SessionReplay,
            "Proxy must stay operational after endpoint is provided"
        )
    }

    func testSessionReplayRemainsOperationalWithTraceOnlyEndpoint() throws {
        let configuration = buildConfigurationWithoutEndpoint()
        let moduleConfigurations: [Any] = [
            SessionReplayConfiguration(enabled: true, samplingRate: 1.0)
        ]

        let installedAgent = try SplunkRum.install(
            with: configuration,
            moduleConfigurations: moduleConfigurations
        )

        XCTAssertTrue(installedAgent.sessionReplayProxy is SessionReplay)

        let traceUrl = try ConfigurationTestBuilder.customUrl(for: ConfigurationTestBuilder.customTraceAddress)
        let traceOnlyEndpoint = EndpointConfiguration(trace: traceUrl)
        try installedAgent.updateEndpoint(traceOnlyEndpoint)

        XCTAssertTrue(
            installedAgent.sessionReplayProxy is SessionReplay,
            "Trace-only endpoint must not affect the already-operational proxy"
        )
    }


    // MARK: - Self-Instrumentation Prevention

    func testUpdateEndpointExcludesCollectorUrlsBeforeFlush() throws {
        let configuration = buildConfigurationWithoutEndpoint()
        let installedAgent = try SplunkRum.install(with: configuration)

        // Before endpoint is set, no collector URLs should be excluded
        let networkModule = installedAgent.modulesManager?
            .module(
                ofType: SplunkNetwork.NetworkInstrumentation.self
            )
        XCTAssertNil(
            networkModule?.excludedEndpoints,
            "No exclusions expected when agent starts without an endpoint"
        )

        // Set the endpoint — exclusions must be in place before the internal flush
        let endpoint = EndpointConfiguration(
            realm: ConfigurationTestBuilder.realm,
            rumAccessToken: ConfigurationTestBuilder.rumAccessToken
        )
        try installedAgent.updateEndpoint(endpoint)

        // After endpoint update, collector URLs must be excluded so flush traffic is not self-instrumented
        let excludedEndpoints = try XCTUnwrap(
            networkModule?.excludedEndpoints,
            "Excluded endpoints should be set after updateEndpoint"
        )

        let traceUrl = try XCTUnwrap(endpoint.traceEndpoint)
        XCTAssertTrue(
            excludedEndpoints.contains(traceUrl),
            "Trace collector URL should be excluded to prevent self-instrumentation of flush traffic"
        )
    }

    func testUpdateEndpointTransitionsExclusionsFromInitialEndpoint() throws {
        let configuration = try ConfigurationTestBuilder.buildDefault()
        let installedAgent = try SplunkRum.install(with: configuration)

        let networkModule = installedAgent.modulesManager?
            .module(
                ofType: SplunkNetwork.NetworkInstrumentation.self
            )

        // Agent started with an endpoint — its collector URLs should already be excluded
        let initialExclusions = try XCTUnwrap(networkModule?.excludedEndpoints)
        let initialTraceUrl = try XCTUnwrap(configuration.endpoint?.traceEndpoint)
        XCTAssertTrue(initialExclusions.contains(initialTraceUrl))

        // Switch to a different endpoint
        let newTraceUrl = try ConfigurationTestBuilder.customUrl(for: ConfigurationTestBuilder.customTraceAddress)
        let newEndpoint = EndpointConfiguration(trace: newTraceUrl)
        try installedAgent.updateEndpoint(newEndpoint)

        // Exclusions should now contain the new collector URL, not the old one
        let updatedExclusions = try XCTUnwrap(networkModule?.excludedEndpoints)
        XCTAssertTrue(
            updatedExclusions.contains(newTraceUrl),
            "New trace collector URL should be excluded after endpoint update"
        )
        XCTAssertFalse(
            updatedExclusions.contains(initialTraceUrl),
            "Previous trace collector URL should no longer be excluded after successful endpoint update"
        )
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
}
