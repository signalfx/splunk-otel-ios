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

/// The agent preferences object represents the preferred settings related to the agent.
public final class AgentPreferences {

    // MARK: - Internal

    private unowned let owner: SplunkRum


    // MARK: - Initialization

    init(for owner: SplunkRum) {
        self.owner = owner
    }
}


extension AgentPreferences {

    // MARK: - Endpoint configuration

    /// The endpoint configuration defining URLs to the instrumentation collector.
    ///
    /// Use this property to dynamically configure or disable the endpoint after the agent has been initialized.
    /// - Setting a non-nil value will configure the endpoint and start sending spans and events.
    /// - Setting nil will disable the endpoint and revert to dropping all spans and events.
    ///
    /// - Note: This property can only be set once the agent is running. Spans created before
    ///         setting this property will not be sent retroactively.
    public var endpointConfiguration: EndpointConfiguration? {
        get {
            owner.currentEndpoint
        }
        set {
            guard let newValue else {
                // Disable the endpoint when nil is passed
                owner.disableEndpoint()
                // Update the current endpoint to nil
                owner.currentEndpoint = nil
                return
            }

            do {
                try owner.updateEndpoint(newValue)
                // Update the current endpoint after successful update
                owner.currentEndpoint = newValue
            }
            catch {
                owner.logger.log(level: .error, isPrivate: false) {
                    "Failed to update endpoint configuration: \(error)"
                }
            }
        }
    }

    /// Sets the endpoint configuration for the agent.
    ///
    /// - Parameter endpoint: The ``EndpointConfiguration`` to use for sending data.
    ///
    /// - Returns: The updated ``AgentPreferences`` object.
    @discardableResult
    public func endpointConfiguration(_ endpoint: EndpointConfiguration) -> AgentPreferences {
        endpointConfiguration = endpoint

        return self
    }
}
