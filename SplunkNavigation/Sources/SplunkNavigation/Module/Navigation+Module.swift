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


/// A data object that represents a navigation event, currently serving as a placeholder to conform to the ``Module`` protocol.
public struct NavigationData: ModuleEventData {}

/// An object that holds metadata for a navigation event.
public struct NavigationMetadata: ModuleEventMetadata {
    /// The timestamp when the navigation event occurred.
    public var timestamp = Date()
}

// Defines Navigation conformance to `Module` protocol
extension Navigation: Module {

    // MARK: - Module types

    /// The configuration type for the Navigation module.
    public typealias Configuration = NavigationConfiguration
    /// The remote configuration type for the Navigation module.
    public typealias RemoteConfiguration = NavigationRemoteConfiguration

    /// The metadata type for navigation events.
    public typealias EventMetadata = NavigationMetadata
    /// The data type for navigation events.
    public typealias EventData = NavigationData


    // MARK: - Module methods

    /// Installs and configures the Navigation module.
    ///
    /// This method sets up the initial preferences based on the provided `configuration`
    /// and starts the navigation detection process unless explicitly disabled.
    ///
    /// - Parameters:
    ///   - configuration: The local configuration settings for the module.
    ///   - remoteConfiguration: The remote configuration settings for the module (currently unused).
    public func install(with configuration: (any ModuleConfiguration)?, remoteConfiguration: (any RemoteModuleConfiguration)?) {
        let configuration = configuration as? Configuration

        // Setup initial configuration
        setup(with: configuration)

        // Start the detection in the module (unless it is explicitly disabled)
        if configuration?.isEnabled ?? true {
            startDetection()
        }
    }

    /// Deletes data associated with a specific event. This method is currently not implemented.
    public func deleteData(for metadata: any ModuleEventMetadata) {}

    /// A closure that is called when new navigation data is ready to be published. This method is currently not implemented.
    public func onPublish(data: @escaping (NavigationMetadata, NavigationData) -> Void) {}


    // MARK: - Private methods

    private func setup(with configuration: Configuration?) {
        guard let configuration else {
            return
        }

        // Update preferences
        preferences.enableAutomatedTracking = configuration.enableAutomatedTracking

        // Update module mode
        let isEnabled = configuration.isEnabled

        Task {
            await model.update(moduleEnabled: isEnabled)
        }
    }
}
