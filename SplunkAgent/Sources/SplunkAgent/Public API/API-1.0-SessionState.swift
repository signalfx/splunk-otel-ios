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

/// A state object that provides read-only access to the current session's state.
public final class SessionState {

    // MARK: - Internal

    // The SplunkRum instance that owns this session state.
    private unowned let owner: SplunkRum


    // MARK: - Initialization

    /// Initializes the session state with its owning `SplunkRum` instance.
    init(for owner: SplunkRum) {
        self.owner = owner
    }
}

public extension SessionState {

    // MARK: - Public properties

    /// The unique identifier of the current session.
    ///
    /// A session ID is always available when the agent is initialized.
    var id: String {
        owner.currentSession.currentSessionId
    }

    /// The sampling rate applied to the current session.
    ///
    /// This is a value between 0.0 and 1.0 that determines the percentage of sessions being recorded.
    var samplingRate: Double {
        owner.agentConfiguration.session.samplingRate
    }
}