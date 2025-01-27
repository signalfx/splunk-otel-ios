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

import Combine
import Foundation

/// A state object that is representation for the current state of the Agent.
///
/// The individual properties are a combination of:
/// - Default SDK settings.
/// - Initial configuration specified by  ``Configuration``.
/// - Settings retrieved from the backend.
///
/// - Note: The states of individual properties in this class can
///         change during the application's runtime.
///
/// The class conforms to `Combine.ObservableObject` protocol to make
/// the published properties available for Combine and SwiftUI.
///
public final class RuntimeState: AgentState, ObservableObject {

    // MARK: - Internal

    private unowned let owner: SplunkRum


    // MARK: - Initialization

    init(for owner: SplunkRum) {
        self.owner = owner
    }
}


public extension RuntimeState {

    // MARK: - Agent status

    /// A `Status` of agent recording.
    var status: Status {
        owner.currentStatus
    }


    // MARK: - User configuration

    /// The base address of the server to which the agent is configured.
    var url: URL? {
        owner.agentConfiguration.url
    }

    /// A `String` that contains the name used for the application.
    var appName: String {
        owner.agentConfiguration.appName ?? ""
    }

    /// A `String` that contains the version used for the application.
    var appVersion: String {
        owner.agentConfiguration.appVersion ?? ""
    }
}
