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
import SplunkCommon

/// Event data for NetworkMonitor module events.
public struct NetworkMonitorData: ModuleEventData {}

/// Event metadata for NetworkMonitor module events.
public struct NetworkMonitorMetadata: ModuleEventMetadata {
    /// The timestamp indicating when the network change event occurred.
    public var timestamp = Date()
    /// The name of the event, which is always "network.change".
    public var eventName: String = "network.change"
}

/// Extension that makes NetworkMonitor conform to the Module protocol.
extension NetworkMonitor: Module {

    // MARK: - Module types

    public typealias Configuration = NetworkMonitorConfiguration
    public typealias RemoteConfiguration = NetworkMonitorRemoteConfiguration
    public typealias EventMetadata = NetworkMonitorMetadata
    public typealias EventData = NetworkMonitorData

    // MARK: - Module methods

    /// Installs the NetworkMonitor module with the specified configuration.
    /// 
    /// - Parameters:
    ///   - configuration: The local configuration for the module, or nil for default settings
    ///   - remoteConfiguration: The remote configuration for the module, or nil for default settings
    public func install(with configuration: (any ModuleConfiguration)?,
                        remoteConfiguration: (any RemoteModuleConfiguration)?) {
        let config = configuration as? Configuration

        // Start the network monitor if it's enabled or if no configuration is provided.
        if config?.isEnabled ?? true {
            startDetection()
        }
    }

    // MARK: - Type transparency helpers

    /// Deletes data associated with the specified metadata.
    ///
    /// - Parameter metadata: The metadata identifying the data to delete
    public func deleteData(for metadata: any ModuleEventMetadata) {}

    /// Sets up a callback for when network monitor data is published.
    ///
    /// - Parameter data: The callback closure to execute when data is published
    public func onPublish(data: @escaping (NetworkMonitorMetadata, NetworkMonitorData) -> Void) {}
}
