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


// MARK: - CustomDataTracking implementation


import Foundation
import OpenTelemetryApi
import SplunkLogger



// TODO: Probably `Data` is going to become `Event` in a lot of places to better match the team understanding.
// CustomDataTracking -> CustomEventTracking, SplunkTrackableData -> SplunkTrackableEvent, etc.


class CustomDataTracking {

    public unowned var sharedState: AgentSharedState?

    private let internalLogger = InternalLogger(configuration: .default(subsystem: "Splunk Agent", category: "CustomDataTracking"))

    func track(data: SplunkTrackableData) {

        // TODO: See TODO about attributes in this same location in CustomErrorTracking -
        // the same questions apply here.

        var constrainedAttributes = ConstrainedAttributes<EventAttributeValue>()

        // Convert SplunkTrackableData to attributes and set them with length validation
        for (key, value) in data.toEventAttributes() {
            if !constrainedAttributes.setAttribute(for: key, value: value) {
                internalLogger.log(level: .warning) {
                    "Invalid key or value length for key '\(key)'. Not publishing this event."
                }
                return
            }
        }

        // Emit the span directly using the TelemetryEmitter
        TelemetryEmitter.emitSpan(data: data, sharedState: sharedState, spanName: "CustomDataTracking")
    }
}
