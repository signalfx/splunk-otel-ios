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

/// A state object that reflects the current session's state.
public final class SessionState {

    // MARK: - Internal

    private unowned let owner: SplunkRum


    // MARK: - Initialization

    init(for owner: SplunkRum) {
        self.owner = owner
    }
}

public extension SessionState {

    // MARK: - Public properties

    /// Identification of recorded session.
    ///
    /// When the agent is initialized, there is always some session ID.
    var id: String {
        owner.currentSession.currentSessionId
    }

    /// Value of the currently used session sampling rate.
    var samplingRate: Double {
        owner.agentConfiguration.session.samplingRate
    }
}
