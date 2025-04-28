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
import SplunkLogger
import SplunkSharedProtocols


// MARK: - CustomTracking internal module

public final class CustomTracking {

    public static var instance = CustomTracking()

    // MARK: - Private Properties

    private let internalLogger = InternalLogger(configuration: .default(subsystem: "SplunkCustomTracking", category: "Data"))

    // Shared state
    public unowned var sharedState: AgentSharedState?
    public var onPublishBlock: ((any ModuleEventMetadata, any ModuleEventData) -> Void)?


    // Module conformance
    public required init() {}

    // MARK: - Internal Tracking Methods

    public func track(event: SplunkTrackableEvent) {
        OTelEmitter.emitSpan(data: event, sharedState: sharedState, spanName: "customEvent")
        /*
        guard let onPublishBlock = onPublishBlock else {
            print("onPublish block not set!")
            return
        }
        let metadata = InternalCustomTrackingMetadata()
        let data = InternalCustomTrackingData(name: event.typeName, attributes: event.toEventAttributes())
        onPublishBlock(metadata, data)
         */
    }

    public func track(issue: SplunkTrackableIssue, attributes: [String: Any]) {
        OTelEmitter.emitSpan(data: issue, sharedState: sharedState, spanName: "customError")
        /*
        guard let onPublishBlock = onPublishBlock else {
            print("onPublish block not set!")
            return
        }
        let metadata = InternalCustomTrackingMetadata()
        // Convert public-facing attributes to internal EventAttributeValue
        let convertedAttributes = attributes.mapValues { EventAttributeValue.convert(from: $0) }
        var allAttributes = convertedAttributes
        for (key, value) in issue.toEventAttributes() {
            allAttributes[key] = value
        }
        let data = InternalCustomTrackingData(name: issue.typeName, attributes: allAttributes)
        onPublishBlock(metadata, data)
        */
    }

    private struct InternalCustomTrackingMetadata: ModuleEventMetadata {
        public var timestamp = Date()
    }

    private struct InternalCustomTrackingData: ModuleEventData {
        public let name: String
        public let attributes: [String: EventAttributeValue]
    }
}


private extension EventAttributeValue {
    static func convert(from value: Any) -> EventAttributeValue {
        switch value {
        case let stringValue as String:
            return .string(stringValue)
        case let intValue as Int:
            return .int(intValue)
        case let doubleValue as Double:
            return .double(doubleValue)
        case let dataValue as Data:
            return .data(dataValue)
        default:
            return .string(String(describing: value))
        }
    }
}
