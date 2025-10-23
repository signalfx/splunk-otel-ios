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
import SplunkAgent

/// The agent preferences object represents the preferred settings related to the agent.
@objc(SPLKAgentPreferences)
public final class AgentPreferencesObjC: NSObject {

    // MARK: - Internal

    private unowned let owner: SplunkRumObjC


    // MARK: - Endpoint configuration

    /// The endpoint configuration defining URLs to the instrumentation collector.
    ///
    /// Use this property to dynamically configure or disable the endpoint after the agent has been initialized.
    /// - Setting a non-nil value will configure the endpoint and start sending spans and events.
    /// - Setting nil will disable the endpoint and revert to dropping all spans and events.
    ///
    /// - Note: This property can only be set once the agent is running. Spans created before
    ///         setting this property will not be sent retroactively.
    @objc
    public var endpointConfiguration: EndpointConfigurationObjC? {
        get {
            guard let endpoint = owner.agent.preferences.endpointConfiguration else {
                return nil
            }

            return EndpointConfigurationObjC(for: endpoint)
        }
        set {
            if let newValue {
                owner.agent.preferences.endpointConfiguration = newValue.endpointConfiguration()
            }
            else {
                // Pass nil to disable the endpoint
                owner.agent.preferences.endpointConfiguration = nil
            }
        }
    }


    // MARK: - Initialization

    init(for owner: SplunkRumObjC) {
        self.owner = owner
    }
}
