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
import SplunkLogger


// MARK: - EventTracking

class EventTracking {

    var typeName: String
    unowned var sharedState: AgentSharedState?

    private let internalLogger = InternalLogger(configuration: .default(subsystem: "Splunk Agent", category: "CustomEventTracking"))

    func track(event: SplunkTrackableEvent) {

        // Initialize ConstrainedAttributes -- currently used for length validation
        var constrainedAttributes = ConstrainedAttributes<EventAttributeValue>()

        // Obtain attributes from the data
        let attributes = event.toEventAttributes()

        // Validate by trying to set key-value pairs using ConstrainedAttributes
        for (key, value) in attributes {
            if !constrainedAttributes.setAttribute(for: key, value: value) {
                internalLogger.log(level: .warning) {
                    "Invalid key or value length for key '\(key)'. Not publishing this event."
                }
                return
            }
        }

        // Emit the span directly using the TelemetryEmitter
        TelemetryEmitter.emitSpan(data: event, sharedState: sharedState, spanName: "CustomEventTracking")
    }
}
