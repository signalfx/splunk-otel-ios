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

final class API10AgentTests: XCTestCase {

    // MARK: - API Tests

    func testInstall() throws {
        // Agent initialization
        _ = try AgentTestBuilder.buildDefault()

        // Agent install
        let configuration = try ConfigurationTestBuilder.buildDefault()
        var agent: SplunkRum? = SplunkRum.install(with: configuration)

        // The agent should run after install
        let agentStatus = try XCTUnwrap(agent?.state.status)
        let expectedStatus = expectedAgentStatus()
        XCTAssertEqual(agentStatus, expectedStatus)

        // Another attempt to install should return an instance from the previous attempt
        let anotherAgentInstance = SplunkRum.install(with: configuration)
        XCTAssertTrue(agent === anotherAgentInstance)

        agent = nil
    }


    // MARK: - Private methods

    private func expectedAgentStatus() -> Status {
        let isSupportedPlatform = PlatformSupport.current.scope == .full

        return isSupportedPlatform ? .running : .notRunning(.unsupportedPlatform)
    }
}
