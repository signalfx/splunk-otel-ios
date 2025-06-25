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

@testable import SplunkAgent
import XCTest

final class API10ConfigurationTests: XCTestCase {

    // MARK: - Private

    private let customTraceUrl = ConfigurationTestBuilder.customTraceUrl
    private let customSessionReplayUrl = ConfigurationTestBuilder.customSessionReplayUrl
    private let deploymentEnvironment = ConfigurationTestBuilder.deploymentEnvironment
    private let appName = ConfigurationTestBuilder.appName
    private let appVersion = ConfigurationTestBuilder.appVersion
    private let rumAccessToken = ConfigurationTestBuilder.rumAccessToken
    private let realm = ConfigurationTestBuilder.realm


    // MARK: - API Tests

    func testMinimalConfiguration() throws {
        // Minimal initialization
        let minimal = try ConfigurationTestBuilder.buildMinimal()
        XCTAssertNotNil(minimal)

        // Properties (READ)
        XCTAssertEqual(minimal.endpoint.realm, realm)
        XCTAssertEqual(minimal.endpoint.rumAccessToken, rumAccessToken)
        XCTAssertNotNil(minimal.endpoint.traceEndpoint)
        XCTAssertNotNil(minimal.endpoint.sessionReplayEndpoint)
        XCTAssertEqual(minimal.deploymentEnvironment, deploymentEnvironment)
        XCTAssertEqual(minimal.appName, appName)
        XCTAssertNotNil(minimal.appVersion)
        XCTAssertEqual(minimal.enableDebugLogging, ConfigurationDefaults.enableDebugLogging)
        XCTAssertEqual(minimal.session.samplingRate, ConfigurationDefaults.sessionSamplingRate)

        // Deprecated properties (READ)
        XCTAssertTrue(minimal.deprecatedScreenNameSpans)
        XCTAssertFalse(minimal.deprecatedShowVCInstrumentation)
    }

    func testConfiguration() throws {
        // Default initialization
        var full = try ConfigurationTestBuilder.buildDefault()

        // Properties (READ)
        XCTAssertEqual(full.endpoint.realm, realm)
        XCTAssertEqual(full.endpoint.rumAccessToken, rumAccessToken)
        XCTAssertEqual(full.deploymentEnvironment, deploymentEnvironment)
        XCTAssertEqual(full.appName, appName)
        XCTAssertEqual(full.appVersion, appVersion)
        XCTAssertNotNil(full.enableDebugLogging)
        XCTAssertNotNil(full.session.samplingRate)
        XCTAssertNotNil(full.user.trackingMode)
        XCTAssertNotNil(full.globalAttributes)
        XCTAssertNotNil(full.spanInterceptor)
        XCTAssertNotNil(full.endpoint.traceEndpoint)
        XCTAssertNotNil(full.endpoint.sessionReplayEndpoint)

        // Deprecated properties (READ)
        XCTAssertTrue(full.deprecatedScreenNameSpans)
        XCTAssertFalse(full.deprecatedShowVCInstrumentation)

        // Properties (WRITE)
        full.appVersion = "0.1"
        XCTAssertEqual(full.appVersion, "0.1")

        full = full.appVersion("0.2")
        XCTAssertEqual(full.appVersion, "0.2")

        full.enableDebugLogging = true
        XCTAssertEqual(full.enableDebugLogging, true)

        full = full.enableDebugLogging(false)
        XCTAssertEqual(full.enableDebugLogging, false)

        // Deprecated properties (WRITE)
        full.deprecatedScreenNameSpans = false
        XCTAssertFalse(full.deprecatedScreenNameSpans)

        full.deprecatedShowVCInstrumentation = true
        XCTAssertTrue(full.deprecatedShowVCInstrumentation)

        // Session configuration
        full.session.samplingRate = 0.7
        XCTAssertEqual(full.session.samplingRate, 0.7)

        var sessionConfiguration = SessionConfiguration()
        sessionConfiguration.samplingRate = 0.5

        full = full.sessionConfiguration(sessionConfiguration)
        XCTAssertEqual(full.session.samplingRate, 0.5)

        // User configuration
        full.user.trackingMode = .noTracking
        XCTAssertEqual(full.user.trackingMode, .noTracking)

        var userConfiguration = UserConfiguration()
        userConfiguration.trackingMode = .anonymousTracking
        full = full.userConfiguration(userConfiguration)
        XCTAssertEqual(full.user.trackingMode, .anonymousTracking)

        let testAttributes = MutableAttributes(dictionary: ["key_one": .string("value_one")])
        full.globalAttributes = testAttributes
        XCTAssertEqual(full.globalAttributes, testAttributes)

        testAttributes["key_two"] = .string("value_two")
        full = full.globalAttributes(testAttributes)
        XCTAssertEqual(full.globalAttributes, testAttributes)

        // Codable & Equatable

        let fullEncoded = try JSONEncoder().encode(full)
        let fullDecoded = try JSONDecoder().decode(AgentConfiguration.self, from: fullEncoded)

        XCTAssertEqual(full, fullDecoded)
    }

    func testRealmConfiguration() throws {
        // Default initialization
        let configuration = try ConfigurationTestBuilder.buildDefault()

        let traceUrl = try XCTUnwrap(configuration.endpoint.traceEndpoint)

        let urlComponents = try XCTUnwrap(URLComponents(url: traceUrl, resolvingAgainstBaseURL: false))

        XCTAssertEqual(urlComponents.scheme, "https")
        XCTAssertEqual(urlComponents.host, "rum-ingest.\(realm).signalfx.com")
        XCTAssertEqual(urlComponents.path, "/v1/rumotlp")

        let queryItems = try XCTUnwrap(urlComponents.queryItems)
        let authQuery = try XCTUnwrap(queryItems.first)
        XCTAssertEqual(authQuery.name, "auth")
        XCTAssertEqual(authQuery.value, rumAccessToken)
    }

    func testCustomUrlConfiguration() throws {
        // Custom urls initialization
        let configuration = try ConfigurationTestBuilder.buildWithCustomUrls()

        let traceUrl = try XCTUnwrap(configuration.endpoint.traceEndpoint)
        let sessionReplayUrl = try XCTUnwrap(configuration.endpoint.sessionReplayEndpoint)

        XCTAssertEqual(traceUrl, customTraceUrl)
        XCTAssertEqual(sessionReplayUrl, customSessionReplayUrl)
    }

    func testInvalidConfiguration() throws {
        let configuration = try ConfigurationTestBuilder.buildInvalidEndpoint()

        XCTAssertThrowsError(
            try configuration.validate()
        )
    }

    func testConfigurationBuilder() throws {
        let appVersion = "0.0.1 Test"
        let debugLogging = true
        let sampling = 0.4
        let globalAttributes = MutableAttributes(dictionary: ["test": .string("value")])
        let userTrackingMode: UserTrackingMode = .anonymousTracking

        var sessionConfiguration = SessionConfiguration()
        sessionConfiguration.samplingRate = 0.4

        var userConfiguration = UserConfiguration()
        userConfiguration.trackingMode = .anonymousTracking

        // Builder methods
        let configuration = try ConfigurationTestBuilder.buildMinimal()
            .appVersion(appVersion)
            .enableDebugLogging(debugLogging)
            .sessionConfiguration(sessionConfiguration)
            .userConfiguration(userConfiguration)
            .globalAttributes(globalAttributes)
            .spanInterceptor { spanData in
                spanData
            }

        // Check if the data has been written
        XCTAssertEqual(configuration.appVersion, appVersion)
        XCTAssertEqual(configuration.enableDebugLogging, debugLogging)
        XCTAssertEqual(configuration.session.samplingRate, sampling)
        XCTAssertEqual(configuration.user.trackingMode, userTrackingMode)
        XCTAssertEqual(configuration.globalAttributes, globalAttributes)
        XCTAssertNotNil(configuration.spanInterceptor)
    }

    func testConfigurationBuilderDeprecated() throws {
        let screenNameSpans = false
        let showVCInstrumentation = true

        // Deprecated builder methods
        let configuration = try ConfigurationTestBuilder.buildMinimal()
            .deprecatedScreenNameSpans(enabled: screenNameSpans)
            .deprecatedShowVCInstrumentation(showVCInstrumentation)

        // Check if the data has been written
        XCTAssertFalse(configuration.deprecatedScreenNameSpans)
        XCTAssertTrue(configuration.deprecatedShowVCInstrumentation)
    }
}
