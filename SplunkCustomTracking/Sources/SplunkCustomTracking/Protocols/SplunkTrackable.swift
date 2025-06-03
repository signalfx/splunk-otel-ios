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


// MARK: - SplunkTrackable Protocol

/// Protocol defining the base requirements for any item that can be tracked.
/// Foundation for both error tracking and custom data tracking.
public protocol SplunkTrackable {

    /// `Issue` or `Event`
    var typeFamily: String { get }

    /// The type name of the trackable item, used for categorization inside a family.
    /// Example: in the Issue family, `typeName`s are CustomType, Error, NSError, NSException
    var typeName: String { get }

    /// Timestamp when the trackable item was created or when a duration started
    var timestamp: Date { get }

    /// Converts the trackable item to a dictionary representation using `[String: AttributeValue]`.
    func toAttributesDictionary() -> [String: AttributeValue]
}


// MARK: - Default Implementations

public extension SplunkTrackable {

    var timestamp: Date {
        Date()
    }
}

