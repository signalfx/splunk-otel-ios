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

import OpenTelemetryApi
@testable import SplunkAgent
import XCTest

final class API10SplunkRumBuilderTests: XCTestCase {

    // MARK: - Tests lifecycle

    override func setUp() {
        super.setUp()

        SplunkRum.resetSharedInstance()
    }

    override func tearDown() {
        SplunkRum.resetSharedInstance()

        super.tearDown()
    }


    // MARK: - Build method tests

    func testBuildWithValidBeaconConfiguration() {
        let builder = SplunkRumBuilder(
            beaconUrl: "https://example.com/v1/rum",
            rumAuth: "authToken"
        )
            .setApplicationName("MyApp")
            .deploymentEnvironment(environment: "Production")
            .debug(enabled: true)
            .sessionSamplingRatio(samplingRatio: 1)
            .showVCInstrumentation(true)
            .screenNameSpans(enabled: false)

        XCTAssertTrue(builder.build())

        // Verify the shared agent state after full build
        let status = SplunkRum.shared.state.status
        let expected: SplunkAgent.Status = {
            if PlatformSupport.current.scope == .full {
                return .running
            } else {
                return .notRunning(.unsupportedPlatform)
            }
        }()

        XCTAssertEqual(status, expected)
    }

    func testBuildWithValidRealmConfiguration() {
        let builder = SplunkRumBuilder(
            realm: "eu0",
            rumAuth: "token123"
        )
            .setApplicationName("RealmApp")
            .deploymentEnvironment(environment: "Staging")

        XCTAssertTrue(builder.build())

        let status = SplunkRum.shared.state.status
        XCTAssertNotEqual(status, .notRunning(.notInstalled))
        XCTAssertEqual(status, .running)
    }

    func testBuildReturnsSameInstance() {
        let builder = SplunkRumBuilder(
            beaconUrl: "https://example.com/v1/rum",
            rumAuth: "abc"
        )
            .setApplicationName("AppityApp")
            .deploymentEnvironment(environment: "QA")

        XCTAssertTrue(builder.build())
        let first = SplunkRum.shared
        XCTAssertTrue(builder.build())
        let second = SplunkRum.shared

        XCTAssertTrue(first === second)
    }


    // MARK: - Build failure tests

    func testBuildWithMissingAppNameReturnsFalse() {
        let builder = SplunkRumBuilder(
            beaconUrl: "https://example.com/v1/rum",
            rumAuth: "auth"
        )
            .deploymentEnvironment(environment: "Prod")

        XCTAssertFalse(builder.build())
    }

    func testBuildWithMissingEnvironmentReturnsFalse() {
        let builder = SplunkRumBuilder(
            beaconUrl: "https://example.com/v1/rum",
            rumAuth: "auth"
        )
            .setApplicationName("NoEnvApp")

        XCTAssertFalse(builder.build())
    }

    func testBuildWithInvalidBeaconUrlReturnsFalse() {
        let invalidUrl = "not a url"
        let builder = SplunkRumBuilder(
            beaconUrl: invalidUrl,
            rumAuth: "token"
        )
            .setApplicationName("BadUrlApp")
            .deploymentEnvironment(environment: "Dev")

        XCTAssertTrue(builder.build())

        let expectedEncoded = URL(string: invalidUrl)?.absoluteString
        let trace = SplunkRum.shared.agentConfiguration.endpoint.traceEndpoint
        XCTAssertEqual(trace?.absoluteString, expectedEncoded)
    }


    // MARK: - Agent configuration tests

    func testBuildConfigurationProperties() throws {
        let beacon = "https://config.example.com/v1/rum"
        let auth = "cfgToken"
        let builder = SplunkRumBuilder(beaconUrl: beacon, rumAuth: auth)
            .setApplicationName("ConfigApp")
            .deploymentEnvironment(environment: "TestEnv")
            .debug(enabled: true)
            .sessionSamplingRatio(samplingRatio: 0.75)

        XCTAssertTrue(builder.build())
        let config = SplunkRum.shared.agentConfiguration

        XCTAssertEqual(config.appName, "ConfigApp")
        XCTAssertEqual(config.deploymentEnvironment, "TestEnv")
        XCTAssertEqual(config.enableDebugLogging, true)
        XCTAssertEqual(config.session.samplingRate, 0.75)
    }


    // MARK: - Initializers configuration tests

    func testBuildForBeaconInitializer() throws {
        let beaconUrl = "https://endpoint.example.com/v1/rum"
        let auth = "endpointAuth"
        let builder = SplunkRumBuilder(beaconUrl: beaconUrl, rumAuth: auth)
            .setApplicationName("EndpointApp")
            .deploymentEnvironment(environment: "Env")

        XCTAssertTrue(builder.build())
        let config = SplunkRum.shared.agentConfiguration

        // Beacon initializer should preserve the raw URL
        XCTAssertEqual(
            config.endpoint.traceEndpoint?.absoluteString,
            beaconUrl
        )
    }

    func testBuildForRealmInitializer() throws {
        let realm = "eu1"
        let token = "realmAuth"
        let builder = SplunkRumBuilder(realm: realm, rumAuth: token)
            .setApplicationName("RealmTest")
            .deploymentEnvironment(environment: "Env")

        XCTAssertTrue(builder.build())
        let config = SplunkRum.shared.agentConfiguration

        guard let url = config.endpoint.traceEndpoint,
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            XCTFail("traceEndpoint should be a valid URL")
            return
        }

        XCTAssertEqual(comps.scheme, "https")
        XCTAssertEqual(comps.host, "rum-ingest.\(realm).signalfx.com")
        XCTAssertEqual(comps.path, "/v1/rumotlp")

        let authItem = comps.queryItems?.first { $0.name == "auth" }
        XCTAssertEqual(authItem?.value, token)
    }

    func testBuildSlowRenderingDisabledWhenFalse() throws {

        let builder = SplunkRumBuilder(
            beaconUrl: "https://example.com/v1/rum",
            rumAuth: "authToken"
        )
            .setApplicationName("DeprecatedApp")
            .deploymentEnvironment(environment: "Env")
            .slowRenderingDetectionEnabled(false) // Method under test

        XCTAssertTrue(builder.build(), "Builder should successfully build when feature is disabled.")

        // Verify agent is running.
        XCTAssertEqual(SplunkRum.shared.state.status, .running, "The SplunkRum agent should be in the .running state.")

        // Verify operational proxy is installed.
        XCTAssert(
            SplunkRum.shared.slowFrameDetector is SplunkAgent.SlowFrameDetector,
            "The slowFrameDetector proxy should be the OPERATIONAL `SplunkAgent.SlowFrameDetector` type, but it is `\(type(of: SplunkRum.shared.slowFrameDetector))` instead. This means the agent is refusing to install the module when disabled."
        )

        // Safely cast to operational proxy.
        let operationalProxy = try XCTUnwrap(
            SplunkRum.shared.slowFrameDetector as? SplunkAgent.SlowFrameDetector,
            "Failed to cast the proxy to its operational type, even though the type check passed."
        )

        // Verify real module state is disabled.
        XCTAssertFalse(
            operationalProxy.module.state.isEnabled,
            "The isEnabled property on the REAL underlying module's state object should be false."
        )

        // Verify proxy reports disabled state.
        XCTAssertFalse(
            operationalProxy.state.isEnabled,
            "The isEnabled property exposed by the PROXY should be false."
        )
    }

    func testBuildSlowRenderingEnabledWhenTrue() throws {

        let builder = SplunkRumBuilder(
            beaconUrl: "https://example.com/v1/rum",
            rumAuth: "authToken"
        )
            .setApplicationName("DeprecatedApp")
            .deploymentEnvironment(environment: "Env")
            .slowRenderingDetectionEnabled(true) // Method under test

        XCTAssertTrue(builder.build(), "Builder should successfully build when feature is enabled.")

        // Verify agent is running.
        XCTAssertEqual(SplunkRum.shared.state.status, .running, "The SplunkRum agent should be in the .running state.")

        // Verify operational proxy is installed.
        XCTAssert(
            SplunkRum.shared.slowFrameDetector is SplunkAgent.SlowFrameDetector,
            "The slowFrameDetector proxy should be the OPERATIONAL `SplunkAgent.SlowFrameDetector` type, but it is `\(type(of: SplunkRum.shared.slowFrameDetector))` instead. This means the module is not being initialized correctly."
        )

        // Safely cast to operational proxy.
        let operationalProxy = try XCTUnwrap(
            SplunkRum.shared.slowFrameDetector as? SplunkAgent.SlowFrameDetector,
            "Failed to cast the proxy to its operational type, even though the type check passed."
        )

        // Verify real module state is enabled.
        XCTAssertTrue(
            operationalProxy.module.state.isEnabled,
            "The isEnabled property on the REAL underlying module's state object should be true."
        )

        // Verify proxy reports enabled state.
        XCTAssertTrue(
            operationalProxy.state.isEnabled,
            "The isEnabled property exposed by the PROXY should be true."
        )
    }

    func testBuildIgnoresDeprecatedSlowRenderingOptions() throws {

        /// Ignore deprecated slowFrameRendering options:
        /// * slowFrameDetectionThresholdMs
        /// * frozenFrameDetectionThresholdMs

        let builder = SplunkRumBuilder(
            beaconUrl: "https://example.com/v1/rum",
            rumAuth: "authToken"
        )
            .setApplicationName("NoOpApp")
            .deploymentEnvironment(environment: "Env")
            // These deprecated methods should have no effect
            .slowFrameDetectionThresholdMs(thresholdMs: 100)
            .frozenFrameDetectionThresholdMs(thresholdMs: 1000)

        XCTAssertTrue(builder.build(), "Builder should successfully build.")

        // Verify agent is running.
        XCTAssertEqual(SplunkRum.shared.state.status, .running, "The SplunkRum agent should be in the .running state.")

        // Verify operational proxy is installed.
        XCTAssert(
            SplunkRum.shared.slowFrameDetector is SplunkAgent.SlowFrameDetector,
            "The slowFrameDetector proxy should be the OPERATIONAL `SplunkAgent.SlowFrameDetector` type, but it is `\(type(of: SplunkRum.shared.slowFrameDetector))` instead."
        )

        // Safely cast to operational proxy.
        let operationalProxy = try XCTUnwrap(
            SplunkRum.shared.slowFrameDetector as? SplunkAgent.SlowFrameDetector,
            "Failed to cast the proxy to its operational type, even though the type check passed."
        )

        // Verify module is enabled by default.
        XCTAssertTrue(
            operationalProxy.module.state.isEnabled,
            "The real module should be enabled by default when no explicit setting is provided."
        )

        // Verify proxy reports default enabled state.
        XCTAssertTrue(
            operationalProxy.state.isEnabled,
            "The proxy should report the default enabled state."
        )
    }

    func testBuildForGlobalAttributesInitializer() throws {
        let realm = "us0"
        let token = "auth-token"
        let builder = SplunkRumBuilder(realm: realm, rumAuth: token)
            .setApplicationName("GlobalAttributesTest")
            .deploymentEnvironment(environment: "Dev")
            .globalAttributes(globalAttributes: ["key1": "value1", "key2": true])

        XCTAssertTrue(builder.build())

        let config = SplunkRum.shared.agentConfiguration
        XCTAssertTrue(config.globalAttributes.attributes.contains(key: "key1"))
        XCTAssertTrue(config.globalAttributes.attributes.contains(key: "key2"))
        XCTAssertEqual(config.globalAttributes.attributes["key1"], AttributeValue.string("value1"))
        XCTAssertEqual(config.globalAttributes.attributes["key2"], AttributeValue.bool(true))
    }
}
