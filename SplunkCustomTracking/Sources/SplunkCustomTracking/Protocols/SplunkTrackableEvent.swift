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
import OpenTelemetryApi
import SplunkCommon


// MARK: - SplunkTrackableEvent Struct

public struct SplunkTrackableEvent: SplunkTrackable {
    public var timestampEnd: Date?
    public var typeName: String
    public var attributes: [String: EventAttributeValue]

    // Simplified initializer for events
    public init(typeName: String, attributes: [String: EventAttributeValue] = [:]) {
        self.typeName = typeName
        self.attributes = attributes
    }

    public func toAttributesDictionary() -> [String: EventAttributeValue] {
        return attributes
    }
}


// MARK: - Protocol Conformance Extension

public extension SplunkTrackableEvent {
    var typeFamily: String {
        "Event"
    }
}
