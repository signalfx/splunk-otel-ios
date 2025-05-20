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
import CiscoLogger
import SplunkCommon

struct DebugEmitter {

    // Logger for logging messages
    private let internalLogger = InternalLogger(configuration: .default(subsystem: "Splunk Agent", category: "LogCustomTracking"))

    public func emitLog(data: SplunkTrackable, sharedState: AgentSharedState?) {

        // Prepare attributes for logging
        var attributes = data.toEventAttributes()
        attributes["component"] = .string("customtracking")
        attributes["screen.name"] = .string("unknown")
        if let sessionID = sharedState?.sessionId {
            attributes["session.id"] = .string(sessionID)
        }

        // Log the attributes
        internalLogger.log(level: .info) {
            "Sending custom data: \(attributes.debugDescription)"
        }
    }
}
