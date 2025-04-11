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

/// Creates and sends an OpenTelemetry span from supplied app start data.
struct OTelDestination: AppStartDestination {

    // MARK: - Sending

    func send(type: AppStartType, start: Date, end: Date, sharedState: (any AgentSharedState)?, events: [String: Date]?) {
        let tracer = OpenTelemetry.instance
            .tracerProvider
            .get(
                instrumentationName: "splunk-app-start",
                instrumentationVersion: sharedState?.agentVersion
            )

        let span = tracer.spanBuilder(spanName: "AppStart")
            .setStartTime(time: start)
            .startSpan()

        span.setAttribute(key: "component", value: "appstart")
        span.setAttribute(key: "start.type", value: typeIdentifier(for: type))

        if let sessionID = sharedState?.sessionId {
            span.setAttribute(key: "session.id", value: sessionID)
        }

        span.setAttribute(key: "screen.name", value: "unknown")

        events?.forEach { name, timestamp in
            span.addEvent(name: name, timestamp: timestamp)
        }

        span.end(time: end)
    }

    private func typeIdentifier(for type: AppStartType) -> String {
        switch type {
        case .cold:
            return "cold"

        case .warm:
            return "warm"

        case .hot:
            return "hot"
        }
    }
}
