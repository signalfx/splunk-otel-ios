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
import OpenTelemetryApi
import SplunkSharedProtocols


// MARK: - OTelDestination for SlowFrameDetector data

struct OTelDestination: SlowFrameDetectorDestination {

    // MARK: - Sending

    func send(type: String, screenName: String, count: Int, sharedState: AgentSharedState?) {
        let tracer = OpenTelemetry.instance
            .tracerProvider
            .get(
                instrumentationName: "splunk-slow-frame",
                instrumentationVersion: sharedState?.agentVersion
            )

        let span = tracer.spanBuilder(spanName: type)
            // TODO: - Replace with actual start time if available
            .setStartTime(time: Date())
            .startSpan()

        span.setAttribute(key: "component", value: "ui")
        span.setAttribute(key: "count", value: count)
        span.setAttribute(key: "screen.name", value: screenName)

        // TODO: - Replace with actual end time if available
        span.end(time: Date())
    }
}
