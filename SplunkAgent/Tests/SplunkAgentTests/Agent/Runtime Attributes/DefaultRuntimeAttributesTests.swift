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

import XCTest

@testable import SplunkAgent

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


        XCTAssertEqual(systemAttributes.count, 3)
        XCTAssertNotNil(systemAttributes["app.installation.id"])
        XCTAssertEqual(systemAttributes["session.id"] as? String, defaultSession.currentSessionId)
        XCTAssertEqual(systemAttributes["user.anonymous_id"] as? String, nil)

        XCTAssertEqual(customAttributes.count, 1)

        XCTAssertEqual(anonymousSystemAttributes.count, 4)
        XCTAssertNotNil(anonymousSystemAttributes["app.installation.id"])
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
        XCTAssertEqual(allAttributes.count, 4)
        XCTAssertEqual(allAttributes[sessionName] as? String, agent.currentSession.currentSessionId)
        XCTAssertEqual(allAttributes[customName] as? String, customValue)
        XCTAssertEqual(customAttributes.count, 2)
        XCTAssertEqual(customAttributes[customName] as? String, customValue)

        XCTAssertEqual(updatedAllAttributes.count, 4)
        XCTAssertEqual(updatedAllAttributes[sessionName] as? String, agent.currentSession.currentSessionId)
        XCTAssertEqual(updatedCustomAttributes.count, 2)
        XCTAssertEqual(updatedCustomAttributes[customName] as? String, updatedValue)

        XCTAssertEqual(finalAllAttributes.count, 3)
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
        XCTAssertEqual(allAttributes.count, 3)
        XCTAssertEqual(allAttributes[systemName] as? String, agent.currentSession.currentSessionId)

        XCTAssertEqual(customAttributes.count, 2)
        XCTAssertEqual(customAttributes[systemName] as? String, customValue)
    }

    func testAppInstallationIdPersistence() throws {
        let storage = UserDefaultsStorage()
        let storageKey = "app.installation.id"

        // Generation and persistence
        try? storage.delete(forKey: storageKey)
        let agent1 = try AgentTestBuilder.buildDefault()
        let attrs1 = DefaultRuntimeAttributes(for: agent1)
        let id1 = attrs1.all["app.installation.id"] as? String

        XCTAssertNotNil(id1, "app.installation.id should be generated.")
        if let id1 {
            XCTAssertNotNil(UUID(uuidString: id1), "Generated ID should be a valid UUID.")
        }

        let stored: String? = try? storage.read(forKey: storageKey)
        XCTAssertEqual(stored, id1, "Generated ID should be persisted.")

        // Retrieval
        let agent2 = try AgentTestBuilder.buildDefault()
        let attrs2 = DefaultRuntimeAttributes(for: agent2)
        let id2 = attrs2.all["app.installation.id"] as? String

        XCTAssertEqual(id1, id2, "Subsequent initializations should retrieve the same ID.")

        try? storage.delete(forKey: storageKey)
    }
}
