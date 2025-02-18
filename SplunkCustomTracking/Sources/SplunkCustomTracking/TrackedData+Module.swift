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

// `Data` can be used as an event type that the module produces.
extension Data: ModuleEventData {}

// Struct `TrackedDataEventMetadata` describes event metadata.
// This type must be unique in the module/agent space.
extension TrackedDataEventMetadata: ModuleEventMetadata {
    public static func == (lhs: TrackedDataEventMetadata, rhs: TrackedDataEventMetadata) -> Bool {
        lhs.id == rhs.id
    }
}

// Defines TrackedData conformance to `Module` protocol
// and implements methods that are missing in the original `TrackedData`.
extension TrackedData: Module {


    // MARK: - Module types

    public typealias Configuration = TrackedDataConfiguration
    public typealias RemoteConfiguration = TrackedDataRemoteConfiguration

    public typealias EventData = Data


    // MARK: - Module methods

    public func install(with configuration: (any ModuleConfiguration)?, remoteConfiguration: (any RemoteModuleConfiguration)?) {
        if let configuration = configuration as? TrackedDataConfiguration {
            print("known configuration")
            print(configuration)
        }
    }


    // MARK: - Type transparency helpers

    public func deleteData(for metadata: any ModuleEventMetadata) {
        // TODO: Code TBD
    }

    public func onPublish(data: @escaping (TrackedDataEventMetadata, EventData) -> Void) {
        // TODO: Code TBD
    }
}
