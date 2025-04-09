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
import SplunkSharedProtocols


struct SpanDataEmitter {

    public func setupSpanEmitter() {
        onPublish { metadata: CustomTrackingEventMetadata, eventData: CustomTrackingEventData in

            let start = Time.now()

            let tracer = OpenTelemetry.instance
                .tracerProvider
                .get(
                    instrumentationName: "splunk-custom-tracking",
                    instrumentationVersion: "0.0.0"
                )

            let span = tracer.spanBuilder(spanName: "CustomTracking")
                .setStartTime(time: start)
                .startSpan()
            span.setAttribute(key: "component", value: "customtracking")

            // Populate span with attributes
            let attributes = eventData.getAttributes()

            if let sessionID = sharedState?.sessionId {
                span.setAttribute(key: "session.id", value: sessionID)
            }

            span.setAttribute(key: "screen.name", value: "unknown")

            attributes.forEach { key, value in
                span.setAttribute(key: key, value: value.toString())
            }

            span.end(time: Date.now())
        }
    }
}

