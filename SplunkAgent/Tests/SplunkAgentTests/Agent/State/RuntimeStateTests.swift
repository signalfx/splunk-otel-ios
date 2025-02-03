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

import SplunkAgent
import XCTest

final class RuntimeStateTests: XCTestCase {

    // MARK: - Tests

    func testProperties() throws {
        let endpointUrl = URL(string: "http://sampledomain.com/tenant")

        // Prepare agent instance
        let configuration = Configuration(url: endpointUrl!)
        let agent = try AgentTestBuilder.build(with: configuration)

        // Properties with minimal agent configuration (READ)
        let state = agent.state

        let agentStatus = state.status
        XCTAssertEqual(agentStatus, .notRunning(.notEnabled))

        let appName = state.appName
        XCTAssertEqual(appName, "com.apple.dt.xctest.tool")

        let appVersion = state.appVersion
        XCTAssertNotNil(appVersion)
    }

    func testEmptyProperties() throws {
        let endpointUrl = URL(string: "http://sampledomain.com/tenant")

        // Prepare minimal "empty" configuration
        var configuration = Configuration(url: endpointUrl!)
        configuration.appName = nil
        configuration.appVersion = nil

        // Prepare agent instance
        let agent = try AgentTestBuilder.build(with: configuration)

        // Properties with minimal agent configuration (READ)
        let state = agent.state

        XCTAssertEqual(state.appName, "")
        XCTAssertEqual(state.appVersion, "")
    }
}
