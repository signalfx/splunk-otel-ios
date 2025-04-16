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


public struct SplunkTrackableEvent: SplunkTrackable {
    public var typeName: String
    public var attributes: [String: EventAttributeValue]

    public var timestamp: Date {
        return Date()
    }

    public init(typeName: String, attributes: [String: EventAttributeValue] = [:]) {
        self.typeName = typeName
        self.attributes = attributes
    }

    // Set methods for various types
    public mutating func set(_ key: String, value: Int) {
        attributes[key] = .int(value)
    }

    public mutating func set(_ key: String, value: String) {
        attributes[key] = .string(value)
    }

    public mutating func set(_ key: String, value: Double) {
        attributes[key] = .double(value)
    }

    public mutating func set(_ key: String, value: Data) {
        attributes[key] = .data(value)
    }

    public mutating func set(_ key: String, value: EventAttributeValue) {
        attributes[key] = value
    }

    public func get(_ key: String) -> EventAttributeValue? {
        return attributes[key]
    }

    public func toEventAttributes() -> [String: EventAttributeValue] {
        return attributes
    }
}
