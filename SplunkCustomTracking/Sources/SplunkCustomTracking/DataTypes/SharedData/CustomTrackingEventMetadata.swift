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


// MARK: - CustomTrackingEventType enum

enum CustomTrackingEventType {
    case error
    case custom
}


// MARK: - CustomTrackingEventMetadata

struct CustomTrackingEventMetadata: ModuleEventMetadata {

    // MARK: - Common properties
    let timestamp: Date
    let id: String
    let eventType: CustomTrackingEventType

    // MARK: - Specific attributes
    private let specificAttributes: [String: String]

    // MARK: - Initialization
    init(timestamp: Date = Date(), id: String = UUID().uuidString, eventType: CustomTrackingEventType, attributes: [String: String] = [:]) {
        self.timestamp = timestamp
        self.id = id
        self.eventType = eventType
        self.specificAttributes = attributes
    }

    func getAttributes() -> [String: String] {
        return specificAttributes
    }
}

// MARK: - Equatable conformance
extension CustomTrackingEventMetadata: Equatable {
    static func == (lhs: CustomTrackingEventMetadata, rhs: CustomTrackingEventMetadata) -> Bool {
        return lhs.id == rhs.id && lhs.timestamp == rhs.timestamp && lhs.eventType == rhs.eventType
    }
}
