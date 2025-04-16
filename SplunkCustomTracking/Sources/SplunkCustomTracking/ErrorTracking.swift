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


// MARK: - ErrorTracking

struct ErrorTracking {

    var typeName: String = ""
    unowned var sharedState: AgentSharedState?

    private let internalLogger = InternalLogger(configuration: .default(subsystem: "Splunk Agent", category: "ErrorTracking"))

    /// Unified track method for SplunkTrackableIssue, Error, NSError, NSException, and wrapped String.
    func track(_ issue: SplunkTrackableIssue) {
        let attributes = issue.toEventAttributes()

        guard validateAttributeLengths(attributes: attributes, logger: internalLogger) else {
            return
        }

        TelemetryEmitter.emitSpan(data: issue, sharedState: sharedState, spanName: "ErrorTracking")
    }
}
