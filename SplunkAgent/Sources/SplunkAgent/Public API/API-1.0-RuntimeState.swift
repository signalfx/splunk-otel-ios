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

import Combine
import Foundation

/// An observable object that represents the current runtime state of the agent.
///
/// This class provides read-only access to the agent's configuration and status.
/// The values are a combination of:
/// - Default SDK settings.
/// - The initial ``AgentConfiguration`` provided by the user.
/// - Settings retrieved from the backend.
///
/// - Note: The state of individual properties can change during the application's runtime.
///
/// This class conforms to `Combine.ObservableObject`, allowing you to subscribe to state
/// changes in SwiftUI and other Combine-based frameworks.
public final class RuntimeState: AgentState, ObservableObject {

    // MARK: - Internal

    // The SplunkRum instance that owns and provides the runtime state.
    private unowned let owner: SplunkRum


    // MARK: - Initialization

    /// Initializes the runtime state with its owning `SplunkRum` instance.
    init(for owner: SplunkRum) {
        self.owner = owner
    }
}


public extension RuntimeState {

    // MARK: - Agent status

    /// The current recording status of the agent.
    var status: Status {
        owner.currentStatus
    }


    // MARK: - User configuration

    /// The name of the application.
    var appName: String {
        owner.agentConfiguration.appName
    }

    /// The version of the application.
    var appVersion: String {
        owner.agentConfiguration.appVersion
    }

    /// The endpoint configuration for the agent.
    ///
    /// See ``EndpointConfiguration`` for more details.
    var endpointConfiguration: EndpointConfiguration {
        owner.agentConfiguration.endpoint
    }

    /// The deployment environment of the application (e.g., `dev`, `production`).
    var deploymentEnvironment: String {
        owner.agentConfiguration.deploymentEnvironment
    }

    /// A Boolean value indicating whether debug logging is enabled.
    var isDebugLoggingEnabled: Bool {
        owner.agentConfiguration.enableDebugLogging
    }
}