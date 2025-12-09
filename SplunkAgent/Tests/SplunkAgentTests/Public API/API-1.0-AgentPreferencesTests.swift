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

import SplunkAgent
import XCTest

final class API10AgentPreferencesTests: XCTestCase {

    // MARK: - API Tests

    func testPreferences() throws {
        // Touch `AgentPreferences` property
        let agent = try AgentTestBuilder.buildDefault()
        let agentPreferences = agent.preferences
        XCTAssertNotNil(agentPreferences)


        // Properties (READ)
        let initialEndpoint = agentPreferences.endpointConfiguration
        XCTAssertNotNil(initialEndpoint)


        // Properties (WRITE)
        let newEndpoint = EndpointConfiguration(
            realm: "us0",
            rumAccessToken: "test-token"
        )
        agentPreferences.endpointConfiguration = newEndpoint

        // Verify the endpoint was updated (by reading it back)
        let updatedEndpoint = agentPreferences.endpointConfiguration
        XCTAssertNotNil(updatedEndpoint)
        XCTAssertEqual(updatedEndpoint?.realm, "us0")


        // Test fluent API
        let anotherEndpoint = EndpointConfiguration(
            realm: "us1",
            rumAccessToken: "another-token"
        )
        let returnedPreferences = agentPreferences.endpointConfiguration(anotherEndpoint)
        XCTAssertNotNil(returnedPreferences)

        let finalEndpoint = agentPreferences.endpointConfiguration
        XCTAssertEqual(finalEndpoint?.realm, "us1")
    }

    func testDisableEndpoint() throws {
        // Build agent with an endpoint
        let agent = try AgentTestBuilder.buildDefault()
        let agentPreferences = agent.preferences

        // Verify initial endpoint exists
        XCTAssertNotNil(agentPreferences.endpointConfiguration)

        // Disable the endpoint by setting to nil
        agentPreferences.endpointConfiguration = nil

        // Verify the endpoint is now nil
        XCTAssertNil(agentPreferences.endpointConfiguration)
    }
}
