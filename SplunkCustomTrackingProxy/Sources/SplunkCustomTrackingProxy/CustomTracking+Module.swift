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
import SplunkCustomTracking
import SplunkSharedProtocols


// `CustomTrackingData` can be used as an event type that the module produces.
public struct CustomTrackingData: ModuleEventData {
    public let name: String
    public let attributes: [String: EventAttributeValue]
}

// Struct `CustomTrackingMetadata` describes event metadata.
public struct CustomTrackingMetadata: ModuleEventMetadata {
    public var timestamp = Date()
}


// Minimal protocol conformance.
public struct CustomTrackingConfiguration: ModuleConfiguration {}

// Minimal protocol conformance.
public struct CustomTrackingRemoteConfiguration: RemoteModuleConfiguration {


    // MARK: - Internal decoding

    struct CustomTracking: Decodable {
        let enabled: Bool
    }

    struct MRUMRoot: Decodable {
        let customTracking: CustomTracking
    }

    struct Configuration: Decodable {
        let mrum: MRUMRoot
    }

    struct Root: Decodable {
        let configuration: Configuration
    }


    // MARK: - Protocol compliance

    public var enabled: Bool = true

    public init?(from data: Data) {
        guard let root = try? JSONDecoder().decode(Root.self, from: data) else {
            return nil
        }

        enabled = root.configuration.mrum.customTracking.enabled
    }
}


// Defines CustomTracking conformance to `Module` protocol
// and implements methods that are missing in the original `CustomTracking`.
extension CustomTracking: Module {

    public typealias Configuration = CustomTrackingConfiguration
    public typealias RemoteConfiguration = CustomTrackingRemoteConfiguration

    public typealias EventMetadata = CustomTrackingMetadata
    public typealias EventData = CustomTrackingData

    public func install(with configuration: (any ModuleConfiguration)?, remoteConfiguration: (any SplunkSharedProtocols.RemoteModuleConfiguration)?) {
        _ = CustomTracking.instance
    }

    public func onPublish(data: @escaping (CustomTrackingMetadata, CustomTrackingData) -> Void) {
        CustomTracking.instance.onPublishBlock = { (metadata: any ModuleEventMetadata, customData: any ModuleEventData) in
            guard let metadata = metadata as? CustomTrackingMetadata,
                  let customData = customData as? CustomTrackingData else {
                return
            }
            data(metadata, customData)
        }
    }

    public func deleteData(for metadata: any SplunkSharedProtocols.ModuleEventMetadata) {}
}
