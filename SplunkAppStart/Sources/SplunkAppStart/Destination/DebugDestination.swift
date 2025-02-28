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
import SplunkLogger
import SplunkSharedProtocols

/// Stores results for testing purposes and prints results.
class DebugDestination: AppStartDestination {

    // MARK: - Private

    // Stored results
    var type: AppStartType?
    var startTime: Date?
    var endTime: Date?
    var events: [String: Date]?

    // Internal Logger
    let internalLogger = InternalLogger(configuration: .default(subsystem: "Splunk Agent", category: "AppStart"))


    // MARK: - Sending

    func send(type: AppStartType, start: Date, end: Date, sharedState: (any AgentSharedState)?, events: [String: Date]?) {
        self.type = type
        self.events = events

        startTime = start
        endTime = end

        let duration = end.timeIntervalSince(start)

        internalLogger.log(level: .info) {
            "Sending app start: \(type), duration: \(duration)s, events: \(events?.debugDescription ?? "none")"
        }
    }
}
