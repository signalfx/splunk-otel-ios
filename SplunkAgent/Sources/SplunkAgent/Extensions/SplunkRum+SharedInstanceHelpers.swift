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

// MARK: - Internal SplunkRum singleton helpers

extension SplunkRum {

    /// Resets the `shared` singleton instance to a non-operational state.
    ///
    /// This method is intentionally internal to the SDK and serves primarily
    /// as a test helper.
    static func resetSharedInstance() {
        SplunkRum.shared = SplunkRum(
            configurationHandler: ConfigurationHandlerNonOperational(for: AgentConfiguration.emptyConfiguration),
            user: NoOpUser(),
            session: NoOpSession(),
            appStateManager: NoOpAppStateManager(),
            sessionSampler: DefaultAgentSessionSampler()
        )
    }
}
