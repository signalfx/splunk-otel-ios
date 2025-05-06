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
        let realm = "\\//"

        let endpoint = EndpointConfiguration(
            realm: realm,
            rumAccessToken: "token"
        )

        let configuration = AgentConfiguration(
            endpoint: endpoint,
            appName: "App",
            deploymentEnvironment: "test"
        )

        XCTAssertThrowsError(
            try configuration.validate()
        ) { error in
            XCTAssertEqual(error as? AgentConfigurationError, AgentConfigurationError.invalidEndpoint(supplied: endpoint))
        }
    }

    func testInvalidAccessToken() throws {
        let authToken = ""

        let endpoint = EndpointConfiguration(
            realm: "dev",
            rumAccessToken: authToken
        )

        let configuration = AgentConfiguration(
            endpoint: endpoint,
            appName: "App",
            deploymentEnvironment: "test"
        )

        XCTAssertThrowsError(
            try configuration.validate()
        ) { error in
            XCTAssertEqual(error as? AgentConfigurationError, AgentConfigurationError.invalidRumAccessToken(supplied: authToken))
        }
    }
}
