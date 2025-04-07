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

    func send(appStart: AppStartSpanData, agentInitialize: AgentInitializeSpanData?, sharedState: (any AgentSharedState)?) {
        let tracer = OpenTelemetry.instance
            .tracerProvider
            .get(
                instrumentationName: "splunk-app-start",
                instrumentationVersion: sharedState?.agentVersion
            )

        let appStartSpan = tracer.spanBuilder(spanName: "AppStart")
            .setStartTime(time: appStart.start)
            .startSpan()

        appStartSpan.setAttribute(key: "component", value: "appstart")
        appStartSpan.setAttribute(key: "screen.name", value: "unknown")
        appStartSpan.setAttribute(key: "start.type", value: typeIdentifier(for: appStart.type))

        if let sessionID = sharedState?.sessionId {
            appStartSpan.setAttribute(key: "session.id", value: sessionID)
        }

        appStart.events?.forEach { event in
            appStartSpan.addEvent(name: event.name, timestamp: event.timestamp)
        }

        // Create and send the Initialize span as a app start span's child
        if let agentInitialize {
            let initializeSpan = tracer.spanBuilder(spanName: "SplunkRum.initialize")
                .setStartTime(time: agentInitialize.start)
                .setParent(appStartSpan)
                .startSpan()

            initializeSpan.setAttribute(key: "component", value: "appstart")
            initializeSpan.setAttribute(key: "screen.name", value: "unknown")

            // Add config settings
            if let configSettings = agentInitialize.formattedConfigurationSettings {
                initializeSpan.setAttribute(key: "config_settings", value: configSettings)
            }

            // Add events
            agentInitialize.events?.forEach { event in
                initializeSpan.addEvent(name: event.name, timestamp: event.timestamp)
            }

            // Add session id
            if let sessionID = sharedState?.sessionId {
                initializeSpan.setAttribute(key: "splunk.rumSessionId", value: sessionID)
            }

            initializeSpan.end(time: agentInitialize.end)
        }

        appStartSpan.end(time: appStart.end)
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
