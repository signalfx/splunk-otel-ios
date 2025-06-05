//
/*
Copyright 2024 Splunk Inc.

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
        XCTAssertNotNil(full.sessionSamplingRate)
        XCTAssertNotNil(full.globalAttributes)
        XCTAssertNotNil(full.spanInterceptor)
        XCTAssertNotNil(full.endpoint.traceEndpoint)
        XCTAssertNotNil(full.endpoint.sessionReplayEndpoint)


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
        XCTAssertEqual(minimal.sessionSamplingRate, ConfigurationDefaults.sessionSamplingRate)

        // Properties (WRITE)
        full.appVersion = "0.1"
        XCTAssertEqual(full.appVersion, "0.1")

        full = full.appVersion("0.2")
        XCTAssertEqual(full.appVersion, "0.2")

        full.enableDebugLogging = true
        XCTAssertEqual(full.enableDebugLogging, true)

        full = full.enableDebugLogging(false)
        XCTAssertEqual(full.enableDebugLogging, false)

        full.sessionSamplingRate = 0.7
        XCTAssertEqual(full.sessionSamplingRate, 0.7)

        full = full.sessionSamplingRate(0.5)
        XCTAssertEqual(full.sessionSamplingRate, 0.5)

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

        // Builder methods
        let configuration = try ConfigurationTestBuilder.buildMinimal()
            .appVersion(appVersion)
            .enableDebugLogging(debugLogging)
            .sessionSamplingRate(sampling)
            .globalAttributes(globalAttributes)
            .spanInterceptor { spanData in
                spanData
            }

        // Check if the data has been written
        XCTAssertEqual(configuration.appVersion, appVersion)
        XCTAssertEqual(configuration.enableDebugLogging, debugLogging)
        XCTAssertEqual(configuration.sessionSamplingRate, sampling)
        XCTAssertEqual(configuration.globalAttributes, globalAttributes)
        XCTAssertNotNil(configuration.spanInterceptor)
    }
}
