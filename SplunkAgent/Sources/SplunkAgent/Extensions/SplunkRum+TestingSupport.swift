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

import Foundation
internal import SplunkCommon

@_spi(objc)
extension SplunkRum {

    // MARK: - Testing support for the Objective-C API target

    /// Private method for creating test instances of the agent.
    ///
    /// - Parameters:
    ///   - configuration: A configuration for the initial SDK setup.
    ///   - named: A `String` with the name of the test being performed.
    ///
    /// - Returns: An agent instance suitable for performing unit tests.
    ///
    /// - Warning: This method is not meant for client applications and may produce
    ///            unexpected results, which are not supported by the product.
    public static func buildTestInstance(with _: AgentConfiguration, testNamed named: String? = nil) -> SplunkRum {
        let testName = named ?? "agent"

        // Custom key-value storage instance with different keys for testing
        let storageName = "com.splunk.rum.objc.test.\(testName)"
        let storage = buildStorage(named: storageName)

        let handler = ConfigurationHandlerNonOperational(
            for: AgentConfiguration.emptyConfiguration
        )

        // All main objects configured with custom storage
        let sessionModel = SessionsModel(storage: storage)
        let session = DefaultSession(sessionsModel: sessionModel)

        let userModel = UserModel(storage: storage)
        let user = DefaultUser(userModel: userModel)

        let appStateModel = AppStateModel(storage: storage)
        let appStateManager = AppStateManager(appStateModel: appStateModel)

        let sessionSampler = SamplerFactory.alwaysOnSampler()

        // Agent configured for tests
        let agent = SplunkRum(
            configurationHandler: handler,
            user: user,
            session: session,
            appStateManager: appStateManager,
            sessionSampler: sessionSampler
        )

        // Links the current session with the agent
        (agent.currentSession as? DefaultSession)?.owner = agent

        return agent
    }


    // MARK: - Private methods

    private static func buildStorage(named: String) -> KeyValueStorage {
        let keysPrefix = "\(PackageIdentifier.default).\(named)."

        let storage = UserDefaultsStorage()
        storage.keysPrefix = keysPrefix

        return storage
    }
}
