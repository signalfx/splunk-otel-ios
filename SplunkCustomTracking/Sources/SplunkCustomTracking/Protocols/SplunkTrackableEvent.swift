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


// MARK: - SplunkTrackableEvent Struct

public struct SplunkTrackableEvent: SplunkTrackable {
    public var typeName: String
    public var attributes: [String: EventAttributeValue]

    // Initializer for event attributes
    public init(typeName: String, attributes: [String: EventAttributeValue] = [:]) {
        self.typeName = typeName
        self.attributes = attributes
    }

    // Initializer for generic attributes
    public init(typeName: String, attributes: [String: Any] = [:]) {
        self.typeName = typeName
        self.attributes = [:]
        setAttributes(attributes: attributes)
    }

    // Converts trackable item to event attributes
    public func toEventAttributes() -> [String: EventAttributeValue] {
        return attributes
    }
}


// MARK: - Attribute Handling Extension

public extension SplunkTrackableEvent {
    mutating func set(_ key: String, value: Int) {
        attributes[key] = .int(value)
    }

    mutating func set(_ key: String, value: String) {
        attributes[key] = .string(value)
    }

    mutating func set(_ key: String, value: Double) {
        attributes[key] = .double(value)
    }

    mutating func set(_ key: String, value: Data) {
        attributes[key] = .data(value)
    }

    mutating func set(_ key: String, value: EventAttributeValue) {
        attributes[key] = value
    }

    func get(_ key: String) -> EventAttributeValue? {
        return attributes[key]
    }
}


// MARK: - Attribute Initialization Extension

private extension SplunkTrackableEvent {
    mutating func setAttributes(attributes: [String: Any]) {
        for (key, value) in attributes {
            if let stringValue = value as? String {
                set(key, value: .string(stringValue))
            } else if let intValue = value as? Int {
                set(key, value: .int(intValue))
            } else if let doubleValue = value as? Double {
                set(key, value: .double(doubleValue))
            } else if let dataValue = value as? Data {
                set(key, value: .data(dataValue))
            }
        }
    }
}


// MARK: - Protocol Conformance Extension

public extension SplunkTrackableEvent {
    var typeFamily: String {
        "Event"
    }
}
