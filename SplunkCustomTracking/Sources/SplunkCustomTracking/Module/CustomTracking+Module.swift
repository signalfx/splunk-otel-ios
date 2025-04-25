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

public struct CustomTrackingData: ModuleEventData {
    public let name: String
    public let attributes: [String: EventAttributeValue]
}

public struct CustomTrackingMetadata: ModuleEventMetadata {
    public var timestamp = Date()
}

// MARK: - Module type definitions

extension CustomTracking: Module {

    public typealias Configuration = CustomTrackingConfiguration
    public typealias RemoteConfiguration = CustomTrackingRemoteConfiguration

    public typealias EventMetadata = CustomTrackingMetadata
    public typealias EventData = CustomTrackingData

    // MARK: - Module installation

    public func install(with configuration: (any SplunkSharedProtocols.ModuleConfiguration)?,
                        remoteConfiguration: (any SplunkSharedProtocols.RemoteModuleConfiguration)?) {
    }

    public func customize(sharedState: AgentSharedState?) {
        self.sharedState = sharedState
    }

    // MARK: - Module data handling

    public func deleteData(for metadata: any ModuleEventMetadata) {}

    public func onPublish(data: @escaping (CustomTrackingMetadata, CustomTrackingData) -> Void) {
        self.onPublishBlock = data
    }

    // MARK: - Internal tracking methods (to be called from CustomTracking class)

    internal func track(event: SplunkTrackableEvent) {
        guard let onPublishBlock = self.onPublishBlock else {
            print("onPublish block not set!")
            return
        }

        let metadata = CustomTrackingMetadata()
        let data = CustomTrackingData(name: event.typeName, attributes: event.toEventAttributes())
        onPublishBlock(metadata, data)
    }

    internal func track(issue: SplunkTrackableIssue, attributes: [String: Any]) {
        guard let onPublishBlock = self.onPublishBlock else {
            print("onPublish block not set!")
            return
        }

        let metadata = CustomTrackingMetadata()
        var allAttributes = attributes.mapValues { EventAttributeValue.convert(from: $0) }
        issue.toEventAttributes().forEach { (key, value) in
            allAttributes[key] = value
        }
        let data = CustomTrackingData(name: issue.typeName, attributes: allAttributes)
        onPublishBlock(metadata, data)
    }
}
