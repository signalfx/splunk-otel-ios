//
/*
Copyright 2024 Splunk Inc.

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

// Struct `EventMetadataANR` describes event metadata.
// This type must be unique in the module/agent space.
extension EventMetadataANR: ModuleEventMetadata {
    public static func == (lhs: EventMetadataANR, rhs: EventMetadataANR) -> Bool {
        return lhs.timestamp == rhs.timestamp
                   && lhs.id == rhs.id
    }
}

// Defines ANRReporter conformance to `Module` protocol
// and implements methods that are missing in the original `ANRReporter`.
extension ANRReporter: Module {


    // MARK: - Module types

    public typealias Configuration = ANRReporterConfiguration
    public typealias RemoteConfiguration = ANRReporterRemoteConfiguration

    public typealias EventMetadata = EventMetadataANR
    public typealias EventData = Data


    // MARK: - Module methods

    public func install(with configuration: (any ModuleConfiguration)?, remoteConfiguration: (any RemoteModuleConfiguration)?) {
        if let configuration = configuration as? ANRReporterConfiguration {
            print("known configuration")
            print(configuration)
        }
        startANRChecking()
    }


    // MARK: - Type transparency helpers

    public func deleteData(for metadata: any ModuleEventMetadata) {
        // In ANRReporter we don't have any data to delete.
    }

    public func onPublish(data: @escaping (EventMetadataANR, EventData) -> Void) {
        // TODO: Code TBD
    }

}
