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
import SplunkSharedProtocols


// MARK: - Module Type Definitions


extension CustomTracking: Module {
    public typealias Configuration = CustomTrackingConfiguration
    public typealias RemoteConfiguration = CustomTrackingRemoteConfiguration
    public typealias EventMetadata = CustomTrackingEventMetadata
    public typealias EventData = CustomTrackingEventData


    // MARK: - Module Installation

    public func install(
        with configuration: (any ModuleConfiguration)?,
        remoteConfiguration: (any RemoteModuleConfiguration)?
    ) {
        if let config = configuration as? CustomTrackingConfiguration {
            self.config = config
        }
    }

    // MARK: - Module Data Handling

    public func onPublish(data block: @escaping (CustomDataEventMetadata, CustomDataEventData) -> Void) {
        dataConsumer = block
    }

    public func deleteData(for metadata: any ModuleEventMetadata) {
        // No persistent data to clean up for error reporting
    }
}




// MARK: - Module Installation

extension TrackedError {
    public func install(
        with configuration: (any ModuleConfiguration)?,
        remoteConfiguration: (any RemoteModuleConfiguration)?
    ) {
        if let config = configuration as? CustomTrackingConfiguration {
            self.config = config
        }
    }
}


// MARK: - Module Data Handling

extension TrackedError {
}
