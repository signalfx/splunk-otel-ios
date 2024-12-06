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

/// Event describes a unit of information sent by the Agent to backend.
public protocol Event {

    // MARK: - Event Identification

    /// Event domain, constant across all mobile events.
    var domain: String { get }

    /// Event name, specific for each event type.
    var name: String { get set }

    /// Instrumentation scope, defines a module from which the event was generated.
    var instrumentationScope: String { get set }


    // MARK: - Event properties

    /// Session id, identifies a session during which the event occured.
    var sessionID: String? { get set }

    /// Event timestamp. The time at which the event occured.
    var timestamp: Date? { get set }

    /// Event attributes.
    var attributes: [String: EventAttributeValue]? { get set }

    /// Event body, enclosed in `EventAttributeValue`.
    var body: EventAttributeValue? { get set }
}
