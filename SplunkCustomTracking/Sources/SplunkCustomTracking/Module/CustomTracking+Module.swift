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


// Defines CustomTracking conformance to `Module` protocol
// and implements methods that are missing in the original `CustomTracking`.
extension CustomTrackingInternal: Module {

    /// Specifies the local configuration type for this module, ``CustomTrackingConfiguration``.
    public typealias Configuration = CustomTrackingConfiguration
    /// Specifies the remote configuration type for this module, ``CustomTrackingRemoteConfiguration``.
    public typealias RemoteConfiguration = CustomTrackingRemoteConfiguration

    /// Specifies the event metadata type for this module, ``CustomTrackingMetadata``.
    public typealias EventMetadata = CustomTrackingMetadata
    /// Specifies the event data type for this module, ``CustomTrackingData``.
    public typealias EventData = CustomTrackingData

    /// Installs the Custom Tracking module.
    ///
    /// This method ensures the singleton `instance` of `CustomTrackingInternal` is initialized.
    /// - Parameters:
    ///   - configuration: The local module configuration. This is currently unused.
    ///   - remoteConfiguration: The remote module configuration. This is currently unused.
    public func install(with configuration: (any ModuleConfiguration)?, remoteConfiguration: (any SplunkCommon.RemoteModuleConfiguration)?) {
        _ = CustomTrackingInternal.instance
    }

    /// Sets the publishing block for the module.
    ///
    /// The agent's core calls this method to provide a closure that the module must use to emit its tracking data.
    /// - Parameter data: The closure to be called when publishing event data.
    public func onPublish(data: @escaping (CustomTrackingMetadata, CustomTrackingData) -> Void) {
        onPublishBlock = data
    }

    /// Deletes data associated with the given metadata.
    ///
    /// This method is a no-op for the Custom Tracking module as it does not persist data that requires explicit deletion.
    /// - Parameter metadata: The metadata identifying the data to delete.
    public func deleteData(for metadata: any SplunkCommon.ModuleEventMetadata) {}
}
