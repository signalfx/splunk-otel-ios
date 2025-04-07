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

final class API10ConfigurationErrorTests: XCTestCase {

    // MARK: - Configuration error tests

    func testInvalidEndpoint() throws {
        var configuration: AgentConfiguration?
        let endpointConfiguration = EndpointConfiguration(realm: "")

        XCTAssertThrowsError(
            configuration = try AgentConfiguration(
                rumAccessToken: "token",
                endpoint: endpointConfiguration,
                appName: "App",
                deploymentEnvironment: "test"
            )
        ) { error in
            XCTAssertEqual(error as? AgentConfigurationError, AgentConfigurationError.invalidEndpoint(supplied: endpointConfiguration))
        }
        XCTAssertNil(configuration)
    }

    func testInvalidAppName() throws {
        var configuration: AgentConfiguration?
        let endpointConfiguration = EndpointConfiguration(realm: "dev")
        let appName = ""

        XCTAssertThrowsError(
            configuration = try AgentConfiguration(
                rumAccessToken: "token",
                endpoint: endpointConfiguration,
                appName: appName,
                deploymentEnvironment: "test"
            )
        ) { error in
            XCTAssertEqual(error as? AgentConfigurationError, AgentConfigurationError.invalidAppName(supplied: appName))
        }
        XCTAssertNil(configuration)
    }

    func testInvalidAccessToken() throws {
        var configuration: AgentConfiguration?
        let endpointConfiguration = EndpointConfiguration(realm: "dev")
        let authToken = ""

        XCTAssertThrowsError(
            configuration = try AgentConfiguration(
                rumAccessToken: authToken,
                endpoint: endpointConfiguration,
                appName: "App",
                deploymentEnvironment: "test"
            )
        ) { error in
            XCTAssertEqual(error as? AgentConfigurationError, AgentConfigurationError.invalidRumAccessToken(supplied: authToken))
        }
        XCTAssertNil(configuration)
    }


    func testInvalidDeploymentEnvironment() throws {
        var configuration: AgentConfiguration?
        let endpointConfiguration = EndpointConfiguration(realm: "dev")
        let deploymentEnvironment = ""

        XCTAssertThrowsError(
            configuration = try AgentConfiguration(
                rumAccessToken: "token",
                endpoint: endpointConfiguration,
                appName: "App",
                deploymentEnvironment: deploymentEnvironment
            )
        ) { error in
            XCTAssertEqual(error as? AgentConfigurationError, AgentConfigurationError.invalidDeploymentEnvironment(supplied: deploymentEnvironment))
        }
        XCTAssertNil(configuration)
    }
}
