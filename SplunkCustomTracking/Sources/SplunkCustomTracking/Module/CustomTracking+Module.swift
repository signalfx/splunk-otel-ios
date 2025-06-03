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


// `CustomTrackingData` can be used as an event type that the module produces.

// TODO: DEMRUM-861: commented, as there are duplicates in CustomTracking.swift. Delete this?
/*
public struct CustomTrackingData: ModuleEventData {
    public let name: String
    public let attributes: [String: EventAttributeValue]
}

public struct CustomTrackingMetadata: ModuleEventMetadata {
    public var timestamp = Date()
}
 */

// Defines CustomTracking conformance to `Module` protocol
// and implements methods that are missing in the original `CustomTracking`.
extension CustomTrackingInternal: Module {

    public typealias Configuration = CustomTrackingConfiguration
    public typealias RemoteConfiguration = CustomTrackingRemoteConfiguration

    public typealias EventMetadata = CustomTrackingMetadata
    public typealias EventData = CustomTrackingData

    public func install(with configuration: (any ModuleConfiguration)?, remoteConfiguration: (any SplunkCommon.RemoteModuleConfiguration)?) {
        _ = CustomTrackingInternal.instance
    }

    public func onPublish(data: @escaping (CustomTrackingMetadata, CustomTrackingData) -> Void) {
        onPublishBlock = data
    }

    public func deleteData(for metadata: any SplunkCommon.ModuleEventMetadata) {}
}
