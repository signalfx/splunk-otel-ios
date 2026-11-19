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

import SplunkSessionReplayProxy
import XCTest

@testable import SplunkAgent

final class API10SessionReplaySamplingTests: XCTestCase {

    // MARK: - Tests lifecycle

    override func setUp() {
        super.setUp()

        SplunkRum.resetSharedInstance()
    }

    override func tearDown() {
        SplunkRum.resetSharedInstance()

        super.tearDown()
    }


    // MARK: - Default sampling

    func testDefaultSamplingRateWithoutModuleConfiguration() throws {
        let configuration = try ConfigurationTestBuilder.buildDefault()
        let installedAgent = try SplunkRum.install(with: configuration)

        installedAgent.sessionReplay.start()
        defer { installedAgent.sessionReplay.stop() }

        XCTAssertTrue(installedAgent.sessionReplayDecisionMade)
        XCTAssertEqual(installedAgent.sessionReplay.state.samplingRate, 0.2)
    }

    func testDefaultSamplingRateWithDefaultModuleConfiguration() throws {
        let configuration = try ConfigurationTestBuilder.buildDefault()
        let installedAgent = try SplunkRum.install(
            with: configuration,
            moduleConfigurations: [SessionReplayConfiguration()]
        )

        installedAgent.sessionReplay.start()
        defer { installedAgent.sessionReplay.stop() }

        XCTAssertTrue(installedAgent.sessionReplayDecisionMade)
        XCTAssertEqual(installedAgent.sessionReplay.state.samplingRate, 0.2)
    }

    func testDefaultSamplingRateWithDeferredEndpoint() throws {
        let configuration = AgentConfiguration(
            endpoint: nil,
            appName: ConfigurationTestBuilder.appName,
            deploymentEnvironment: ConfigurationTestBuilder.deploymentEnvironment
        )
        let installedAgent = try SplunkRum.install(with: configuration)

        installedAgent.sessionReplay.start()
        defer { installedAgent.sessionReplay.stop() }

        XCTAssertTrue(installedAgent.sessionReplayDecisionMade)
        XCTAssertEqual(installedAgent.sessionReplay.state.samplingRate, 0.2)

        let endpoint = EndpointConfiguration(
            realm: ConfigurationTestBuilder.realm,
            rumAccessToken: ConfigurationTestBuilder.rumAccessToken
        )
        try installedAgent.updateEndpoint(endpoint)

        XCTAssertEqual(installedAgent.sessionReplay.state.samplingRate, 0.2)
    }

    func testDefaultSamplingRateWhenDisabledByConfiguration() throws {
        let configuration = try ConfigurationTestBuilder.buildDefault()
        let installedAgent = try SplunkRum.install(
            with: configuration,
            moduleConfigurations: [SessionReplayConfiguration(enabled: false)]
        )

        installedAgent.sessionReplay.start()
        defer { installedAgent.sessionReplay.stop() }

        XCTAssertTrue(installedAgent.sessionReplayDecisionMade)
        XCTAssertTrue(installedAgent.sessionReplayProxy is SessionReplayNonOperational)
        XCTAssertEqual(installedAgent.sessionReplay.state.samplingRate, 0.2)
        XCTAssertEqual(installedAgent.sessionReplay.state.status, .notRecording(.notStarted))
    }


    // MARK: - Explicit sampling

    func testExplicitSamplingRateOne() throws {
        let configuration = try ConfigurationTestBuilder.buildDefault()
        let installedAgent = try SplunkRum.install(
            with: configuration,
            moduleConfigurations: [SessionReplayConfiguration(samplingRate: 1.0)]
        )

        installedAgent.sessionReplay.start()
        defer { installedAgent.sessionReplay.stop() }

        XCTAssertTrue(installedAgent.sessionReplayProxy is SessionReplay)
        XCTAssertEqual(installedAgent.sessionReplay.state.samplingRate, 1.0)
    }

    func testExplicitSamplingRateZero() throws {
        let configuration = try ConfigurationTestBuilder.buildDefault()
        let installedAgent = try SplunkRum.install(
            with: configuration,
            moduleConfigurations: [SessionReplayConfiguration(samplingRate: 0.0)]
        )

        installedAgent.sessionReplay.start()
        defer { installedAgent.sessionReplay.stop() }

        XCTAssertTrue(installedAgent.sessionReplayProxy is SessionReplayNonOperational)
        XCTAssertEqual(installedAgent.sessionReplay.state.samplingRate, 0.0)
        XCTAssertEqual(installedAgent.sessionReplay.state.status, .notRecording(.disabledBySampling))
    }

    func testExplicitFractionalSamplingRate() throws {
        let configuration = try ConfigurationTestBuilder.buildDefault()
        let installedAgent = try SplunkRum.install(
            with: configuration,
            moduleConfigurations: [SessionReplayConfiguration(samplingRate: 0.75)]
        )

        installedAgent.sessionReplay.start()
        defer { installedAgent.sessionReplay.stop() }

        XCTAssertTrue(installedAgent.sessionReplayDecisionMade)
        XCTAssertEqual(installedAgent.sessionReplay.state.samplingRate, 0.75)
    }
}
