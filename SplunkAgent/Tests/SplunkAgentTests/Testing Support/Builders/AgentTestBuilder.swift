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

final class AgentTestBuilder {

    // MARK: - Basic builds

    public static func buildDefault() throws -> SplunkRum {
        // We use prepared configuration
        let configuration = try ConfigurationTestBuilder.buildDefault()

        // Agent configured for tests
        let agent = try build(with: configuration)

        return agent
    }

    public static func build(with configuration: Configuration, session: AgentSession = DefaultSession()) throws -> SplunkRum {
        // Custom key-value storage instance with different keys for testing
        let storage = UserDefaultsStorageTestBuilder.buildCleanStorage(named: "com.splunk.rum.test.")
        let user = DefaultUser(storage: storage)

        let handler = ConfigurationHandler(
            for: configuration,
            apiClient: APIClientTestBuilder.buildError(),
            storage: storage
        )

        let appStateModel = AppStateModel(storage: storage)
        let appStateManager = AppStateManager(appStateModel: appStateModel)

        // Agent configured for tests
        let agent = SplunkRum(
            configurationHandler: handler,
            user: user,
            session: session,
            appStateManager: appStateManager
        )

        // Links the current session with the agent
        (agent.currentSession as? DefaultSession)?.owner = agent

        return agent
    }
}
