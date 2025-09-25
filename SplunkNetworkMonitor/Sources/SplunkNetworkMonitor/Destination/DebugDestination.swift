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

internal import CiscoLogger
import Foundation
import SplunkCommon

/// Stores results for testing purposes and prints results.
class DebugDestination: NetworkMonitorDestination {

    // MARK: - Private

    /// Internal logger for outputting debug information.
    let logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "NetworkMonitor")

    // MARK: - Sending

    /// Logs a network event for debugging purposes.
    ///
    /// - Parameters:
    ///   - networkEvent: The network change event to log
    ///   - sharedState: The agent's shared state (not used in debug logging)
    func send(networkEvent: NetworkMonitorEvent, sharedState _: (any AgentSharedState)?) {

        logger.log(level: .info) {
            """
            Network Change span:
                timestamp: \(networkEvent.timestamp),
                status: \(networkEvent.isConnected ? "available" : "lost"),
                type: \(networkEvent.connectionType.rawValue),
                subType: \(networkEvent.radioType ?? "na"),
            """
        }
    }
}
