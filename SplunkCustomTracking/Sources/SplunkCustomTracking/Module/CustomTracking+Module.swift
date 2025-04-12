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

public struct CustomTrackingData: ModuleEventData {}

public struct CustomTrackingMetadata: ModuleEventMetadata {
    public var timestamp = Date()
}

// MARK: - Module type definitions

extension SplunkCustomTracking: Module {

    public typealias Configuration = CustomTrackingConfiguration
    public typealias RemoteConfiguration = CustomTrackingRemoteConfiguration

    public typealias EventMetadata = CustomTrackingMetadata
    public typealias EventData = CustomTrackingData


    // MARK: - Module installation

    func install(with configuration: (any SplunkSharedProtocols.ModuleConfiguration)?, remoteConfiguration: (any SplunkSharedProtocols.RemoteModuleConfiguration)?) {
    }


    // MARK: - Module data handling

    public func deleteData(for metadata: any ModuleEventMetadata) {}
    public func onPublish(data: @escaping (CustomTrackingMetadata, CustomTrackingData) -> Void) {}

}
