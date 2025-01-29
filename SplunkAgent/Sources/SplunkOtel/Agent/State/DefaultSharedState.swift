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

import Foundation
@_implementationOnly import SplunkSharedProtocols

/// A shared state is a representation of view on current internal information.
///
/// All contained information is related to the current agent instance.
class DefaultSharedState: AgentSharedState {

    // MARK: - Internal

    private unowned let owner: SplunkRum


    // MARK: - General state

    var sessionId: String {
        owner.currentSession.currentSessionId
    }

    func applicationState(for timestamp: Date) -> String? {
        owner.appStateManager.appState(for: timestamp)?.rawValue
    }


    // MARK: - Initialization

    init(for owner: SplunkRum) {
        self.owner = owner
    }
}
