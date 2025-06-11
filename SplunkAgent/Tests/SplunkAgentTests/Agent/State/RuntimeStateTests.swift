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

final class StateTests: XCTestCase {

    // MARK: - Tests

    func testProperties() throws {

        // Prepare agent instance
        let configuration = try ConfigurationTestBuilder.buildMinimal()
        let agent = try AgentTestBuilder.build(with: configuration)

        // Properties with minimal agent configuration (READ)
        let state = agent.state

        let agentStatus = state.status
        XCTAssertEqual(agentStatus, .notRunning(.notInstalled))

        let appName = state.appName
        XCTAssertEqual(appName, ConfigurationTestBuilder.appName)

        let appVersion = state.appVersion
        XCTAssertNotNil(appVersion)

        let realm = state.endpointConfiguration.realm
        XCTAssertEqual(realm, ConfigurationTestBuilder.realm)

        let deploymentEnvironment = state.deploymentEnvironment
        XCTAssertEqual(deploymentEnvironment, ConfigurationTestBuilder.deploymentEnvironment)

        let debugEnabled = state.isDebugLoggingEnabled
        XCTAssertEqual(debugEnabled, ConfigurationDefaults.enableDebugLogging)
    }
}
