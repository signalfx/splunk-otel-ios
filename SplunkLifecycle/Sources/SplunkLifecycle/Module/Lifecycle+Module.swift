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
import SplunkCommon

/// Event data for Lifecycle module events.
public struct LifecycleData: ModuleEventData {}

/// Event metadata for Lifecycle module events.
public struct LifecycleMetadata: ModuleEventMetadata {
    public var timestamp = Date()
}

/// Defines Lifecycle conformance to the Module protocol.
extension Lifecycle: Module {

    // MARK: - Module types

    public typealias Configuration = LifecycleConfiguration
    public typealias RemoteConfiguration = LifecycleRemoteConfiguration

    public typealias EventMetadata = LifecycleMetadata
    public typealias EventData = LifecycleData


    // MARK: - Module methods

    /// Installs the Lifecycle module with the specified configuration and starts detection when enabled.
    public func install(
        with configuration: (any ModuleConfiguration)?,
        remoteConfiguration _: (any RemoteModuleConfiguration)?
    ) {
        update(configuration: configuration as? Configuration ?? Configuration())

        let activeConfiguration = self.configuration
        guard
            activeConfiguration.isEnabled,
            !activeConfiguration.allowedEvents.isEmpty
        else {
            return
        }

        startDetection()
    }

    /// Deletes data associated with the specified metadata.
    ///
    /// - Parameter metadata: The metadata identifying the data to delete.
    public func deleteData(for metadata: any ModuleEventMetadata) {
        // Lifecycle emits directly through OTel logs, not Module onPublish data.
        _ = metadata
    }

    /// Sets up a callback for when lifecycle data is published.
    ///
    /// - Parameter data: The callback closure to execute when data is published.
    public func onPublish(data: @escaping (LifecycleMetadata, LifecycleData) -> Void) {
        // Lifecycle emits directly through OTel logs, not Module onPublish data.
        _ = data
    }
}
