//
/*
Copyright 2026 Splunk Inc.

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

// MARK: - Endpoint Management

extension SplunkRum {

    /// Updates the endpoint configuration to start sending spans and events.
    ///
    /// Use this method to dynamically configure the endpoint after the agent has been initialized
    /// without an endpoint.
    ///
    /// - Parameter endpoint: The ``EndpointConfiguration`` to use for sending data.
    /// - Throws: ``AgentConfigurationError`` if the provided endpoint is invalid.
    public func updateEndpoint(_ endpoint: EndpointConfiguration) throws {
        // Try to update the event manager if available
        if let eventManager = eventManager as? DefaultEventManager {
            // Temporarily exclude BOTH old and new collector URLs before the
            // endpoint update. This prevents self-instrumentation while keeping the old
            // collector excluded in case the update fails.
            let previousEndpoint = currentEndpoint
            let previousUrls = [previousEndpoint?.traceEndpoint, previousEndpoint?.sessionReplayEndpoint].compactMap(\.self)
            updateNetworkExclusionList(for: endpoint, additionalUrls: previousUrls)

            do {
                try eventManager.updateEndpoint(endpoint)
            }
            catch {
                // Restore exclusions for the still-active old endpoint
                updateNetworkExclusionList(for: previousEndpoint)
                throw error
            }

            currentEndpoint = endpoint
            updateNetworkExclusionList(for: endpoint)

            logger.log(level: .info, isPrivate: false) {
                "Endpoint configuration updated successfully."
            }
        }
        else {
            // Event manager not available, but still store the endpoint for API consistency
            currentEndpoint = endpoint
            logger.log(level: .warn, isPrivate: false) {
                "Endpoint configuration stored but event manager is not available."
            }
        }
    }

    /// Disables the endpoint configuration and stops sending spans and events.
    ///
    /// Data is cached to pending storage for later sending when a new endpoint is
    /// configured via ``updateEndpoint(_:)``.
    public func disableEndpoint() {
        if let eventManager = eventManager as? DefaultEventManager {
            eventManager.disableEndpoint()
            currentEndpoint = nil
            updateNetworkExclusionList(for: nil)

            logger.log(level: .info, isPrivate: false) {
                "Endpoint disabled. Spans will be cached and sent when endpoint is configured."
            }
        }
        else {
            currentEndpoint = nil
            logger.log(level: .warn, isPrivate: false) {
                "Endpoint disabled but event manager is not available."
            }
        }
    }
}
