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
@_spi(SplunkInternal) import SplunkCommon

// MARK: - OTelDestination for SlowFrameDetector data

public struct OTelDestination: SlowFrameDetectorDestination {

    public init() {}

    // MARK: - Sending

    public func send(type: String, count: Int, sharedState: AgentSharedState?) async {

        let tracer = OpenTelemetry.instance
            .tracerProvider
            .get(
                instrumentationName: "splunk-slow-frame",
                instrumentationVersion: sharedState?.agentVersion
            )

        let spanTime = Date()

        let span = tracer.spanBuilder(spanName: type)
            .setStartTime(time: spanTime)
            .startSpan()

        span.clearAndSetAttribute(key: "component", value: "ui")
        span.clearAndSetAttribute(key: "count", value: count)

        span.end(time: spanTime)
    }
}
