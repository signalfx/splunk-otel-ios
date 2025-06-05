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

final class DefaultRuntimeAttributesTests: XCTestCase {

    // MARK: - Basic logic

    func testBusinessLogic() throws {
        let testName = "defaultRuntimeAttributesTest"
        let defaultSession = try DefaultSessionTestBuilder.build(named: testName + "Session")
        let defaultUser = try DefaultUserTestBuilder.build(named: testName + "User")

        let configuration = try ConfigurationTestBuilder.buildMinimal()

        let agent = try AgentTestBuilder.build(
            with: configuration,
            session: defaultSession,
            user: defaultUser
        )
        let runtimeAttributes = agent.runtimeAttributes


        // Get default system attributes list
        agent.user.preferences.trackingMode = .noTracking
        let systemAttributes = runtimeAttributes.all
        let customAttributes = runtimeAttributes.custom

        // Get default system attributes list (with anonymous user tracking)
        agent.user.preferences.trackingMode = .anonymousTracking
        let anonymousSystemAttributes = runtimeAttributes.all
        let anonymousCustomAttributes = runtimeAttributes.custom


        XCTAssertEqual(systemAttributes.count, 2)
        XCTAssertEqual(systemAttributes["session.id"] as? String, defaultSession.currentSessionId)
        XCTAssertEqual(systemAttributes["user.anonymous_id"] as? String, nil)
  
        XCTAssertEqual(customAttributes.count, 1)

        XCTAssertEqual(anonymousSystemAttributes.count, 3)
        XCTAssertEqual(anonymousSystemAttributes["session.id"] as? String, defaultSession.currentSessionId)
        XCTAssertEqual(anonymousSystemAttributes["user.anonymous_id"] as? String, defaultUser.userIdentifier)
        XCTAssertFalse(anonymousCustomAttributes.isEmpty)
    }

    func testCustomAttributes() throws {
        let testName = "customRuntimeAttributesTest"
        let defaultSession = try DefaultSessionTestBuilder.build(named: testName + "Session")
        let defaultUser = try DefaultUserTestBuilder.build(named: testName + "User")

        let configuration = try ConfigurationTestBuilder.buildMinimal()

        let agent = try AgentTestBuilder.build(
            with: configuration,
            session: defaultSession,
            user: defaultUser
        )
        agent.user.preferences.trackingMode = .noTracking

        let runtimeAttributes = agent.runtimeAttributes


        // Add custom attribute
        let customName = "CustomName"
        let customValue = "CustomValue"
        runtimeAttributes.updateCustom(named: customName, with: customValue)

        let allAttributes = runtimeAttributes.all
        let customAttributes = runtimeAttributes.custom

        // Update custom attribute
        let updatedValue = "UpdatedCustomValue"
        runtimeAttributes.updateCustom(named: customName, with: updatedValue)

        let updatedAllAttributes = runtimeAttributes.all
        let updatedCustomAttributes = runtimeAttributes.custom

        // Remove custom attribute
        runtimeAttributes.removeCustom(named: customName)

        let finalAllAttributes = runtimeAttributes.all
        let finalCustomAttributes = runtimeAttributes.custom


        let sessionName = "session.id"
        XCTAssertEqual(allAttributes.count, 3)
        XCTAssertEqual(allAttributes[sessionName] as? String, agent.currentSession.currentSessionId)
        XCTAssertEqual(allAttributes[customName] as? String, customValue)
        XCTAssertEqual(customAttributes.count, 2)
        XCTAssertEqual(customAttributes[customName] as? String, customValue)

        XCTAssertEqual(updatedAllAttributes.count, 3)
        XCTAssertEqual(updatedAllAttributes[sessionName] as? String, agent.currentSession.currentSessionId)
        XCTAssertEqual(updatedCustomAttributes.count, 2)
        XCTAssertEqual(updatedCustomAttributes[customName] as? String, updatedValue)

        XCTAssertEqual(finalAllAttributes.count, 2)
        XCTAssertEqual(finalAllAttributes[sessionName] as? String, agent.currentSession.currentSessionId)
        XCTAssertEqual(finalCustomAttributes.count, 1)
    }

    func testCustomAttributesPriority() throws {
        let testName = "customRuntimeAttributesPriorityTest"
        let defaultSession = try DefaultSessionTestBuilder.build(named: testName + "Session")
        let defaultUser = try DefaultUserTestBuilder.build(named: testName + "User")

        let configuration = try ConfigurationTestBuilder.buildMinimal()

        let agent = try AgentTestBuilder.build(
            with: configuration,
            session: defaultSession,
            user: defaultUser
        )
        agent.user.preferences.trackingMode = .noTracking

        let runtimeAttributes = agent.runtimeAttributes


        // Add custom attribute with same name as system attribute
        let systemName = "session.id"
        let customValue = "CustomValue"
        runtimeAttributes.updateCustom(named: systemName, with: customValue)

        let allAttributes = runtimeAttributes.all
        let customAttributes = runtimeAttributes.custom


        // System attributes always take precedence over custom attributes
        XCTAssertEqual(allAttributes.count, 2)
        XCTAssertEqual(allAttributes[systemName] as? String, agent.currentSession.currentSessionId)

        XCTAssertEqual(customAttributes.count, 2)
        XCTAssertEqual(customAttributes[systemName] as? String, customValue)
    }
}
