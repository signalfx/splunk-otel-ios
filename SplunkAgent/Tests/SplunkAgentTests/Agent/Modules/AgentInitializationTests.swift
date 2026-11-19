//
/*
Copyright 2026 Splunk Inc.

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

import XCTest

@testable import SplunkAgent

final class AgentInitializationTests: XCTestCase {

    func testMakeInitializationMergesModuleTimes() throws {
        let agent = try AgentTestBuilder.buildDefault()
        let modulesManager = try DefaultModulesManagerTestBuilder.buildDefault()
        agent.modulesManager = modulesManager
        let start = Date().addingTimeInterval(-1)
        let instanceInitialized = start.addingTimeInterval(0.1)

        let initialization = try XCTUnwrap(
            agent.makeAgentInitialization(
                start: start,
                initializeEvents: ["agent_instance_initialized": instanceInitialized]
            )
        )

        XCTAssertEqual(initialization.start, start)
        XCTAssertGreaterThanOrEqual(initialization.end, start)
        XCTAssertEqual(initialization.events["agent_instance_initialized"], instanceInitialized)
        XCTAssertFalse(modulesManager.modulesInitializationTimes.isEmpty)
        for (moduleName, time) in modulesManager.modulesInitializationTimes {
            XCTAssertEqual(initialization.events["\(moduleName)_initialized"], time)
        }
        XCTAssertEqual(initialization.events.count, modulesManager.modulesInitializationTimes.count + 1)
        XCTAssertNotNil(initialization.configurationSettings["sessionSamplingRate"])
        XCTAssertNotNil(initialization.configurationSettings["enableDebugLogging"])
    }

    func testMakeInitializationNeedsModulesManager() throws {
        let agent = try AgentTestBuilder.buildDefault()

        XCTAssertNil(agent.makeAgentInitialization(start: Date(), initializeEvents: [:]))
    }
}
