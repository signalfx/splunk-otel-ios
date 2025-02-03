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
@_implementationOnly import SplunkCrashReports
@_implementationOnly import SplunkSharedProtocols

/// Crash Reports data event. Represents stringified Crash Report with metadata.
class CrashReportsDataEvent: AgentEvent {

    // MARK: - Initialization

    /// Initializes a Crash Report data event.
    ///
    /// - Parameters:
    ///   - metadata: `CrashReportsMetadata` describing the actual Crash Report event metadata.
    ///   - data: Crash Report data serialized as a `String`.
    ///   - sessionID: The `session ID` of a session in which the event occured.
    public init(metadata: CrashReportsMetadata, data: String, sessionID: String?) {
        super.init()

        // Event identification
        name = metadata.eventName

        instrumentationScope = "com.splunk.rum.crashreports"

        if let sessionID {
            self.sessionID = sessionID
        }

        timestamp = metadata.timestamp
        body = EventAttributeValue(data)
    }
}
