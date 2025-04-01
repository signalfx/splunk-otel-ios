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

    private let customTracesUrl = ConfigurationTestBuilder.customTracesUrl
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
        XCTAssertEqual(full.deploymentEnvironment, deploymentEnvironment)
        XCTAssertEqual(full.appName, appName)
        XCTAssertEqual(full.rumAccessToken, rumAccessToken)
        XCTAssertEqual(full.appVersion, appVersion)
        XCTAssertNotNil(full.enableDebugLogging)
        XCTAssertNotNil(full.sessionSamplingRate)
        XCTAssertNotNil(full.globalAttributes)
        XCTAssertNotNil(full.spanFilter)
        XCTAssertNotNil(full.tracesUrl)
        XCTAssertNil(full.sessionReplayUrl)
        XCTAssertNotNil(full.logsUrl)
        XCTAssertNotNil(full.configUrl)


        // Minimal initialization
        let minimal = try ConfigurationTestBuilder.buildMinimal()
        XCTAssertNotNil(minimal)

        // Properties (READ)
        XCTAssertEqual(minimal.endpoint.realm, realm)
        XCTAssertEqual(minimal.deploymentEnvironment, deploymentEnvironment)
        XCTAssertEqual(minimal.appName, appName)
        XCTAssertEqual(minimal.rumAccessToken, rumAccessToken)
        XCTAssertNotNil(minimal.appVersion)
        XCTAssertEqual(minimal.enableDebugLogging, ConfigurationDefaults.enableDebugLogging)
        XCTAssertEqual(minimal.sessionSamplingRate, ConfigurationDefaults.sessionSamplingRate)
        XCTAssertNil(minimal.sessionReplayUrl)
        XCTAssertNotNil(minimal.tracesUrl)
        XCTAssertNotNil(minimal.logsUrl)
        XCTAssertNotNil(minimal.configUrl)


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

        var testAttributes = ["key_one": "value_one"]
        full.globalAttributes = testAttributes
        XCTAssertEqual(full.globalAttributes, testAttributes)

        testAttributes["key_two"] = "value_two"
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

        let tracesUrl = configuration.tracesUrl

        let urlComponents = try XCTUnwrap(URLComponents(url: tracesUrl, resolvingAgainstBaseURL: false))

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

        let tracesUrl = configuration.tracesUrl
        let sessionReplayUrl = try XCTUnwrap(configuration.sessionReplayUrl)

        XCTAssertTrue(tracesUrl.absoluteString.hasPrefix(customTracesUrl.absoluteString))
        XCTAssertTrue(sessionReplayUrl.absoluteString.hasPrefix(customSessionReplayUrl.absoluteString))

        // Make sure we do supply access token to customer's custom url
        let urlComponents = try XCTUnwrap(URLComponents(url: tracesUrl, resolvingAgainstBaseURL: false))
        XCTAssertTrue(urlComponents.queryItems?.count ?? 0 > 0)
    }

    func testConfigurationBuilder() throws {
        let appVersion = "0.0.1 Test"
        let debugLogging = true
        let sampling = 0.4
        let globalAttributes = ["test": "value"]

        // Builder methods
        let configuration = try ConfigurationTestBuilder.buildMinimal()
            .appVersion(appVersion)
            .enableDebugLogging(debugLogging)
            .sessionSamplingRate(sampling)
            .globalAttributes(globalAttributes)
            .spanFilter { spanData in
                spanData
            }

        // Check if the data has been written
        XCTAssertEqual(configuration.appVersion, appVersion)
        XCTAssertEqual(configuration.enableDebugLogging, debugLogging)
        XCTAssertEqual(configuration.sessionSamplingRate, sampling)
        XCTAssertEqual(configuration.globalAttributes, globalAttributes)
        XCTAssertNotNil(configuration.spanFilter)
    }
}
