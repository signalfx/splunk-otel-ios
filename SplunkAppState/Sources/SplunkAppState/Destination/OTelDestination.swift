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
import SplunkCommon

/// Creates and sends an OpenTelemetry span from supplied app start data.
class OtelDestination: AppStateDestination {

    func send(appState: AppStateType, time: Date, sharedState: AgentSharedState?) {

        let tracer = OpenTelemetry.instance
            .tracerProvider
            .get(
                instrumentationName: "app-lifecycle",
                instrumentationVersion: sharedState?.agentVersion
            )

        let appStateSpan = tracer.spanBuilder(spanName: "device.app.lifecycle")
            .setStartTime(time: time)
            .startSpan()

        appStateSpan.setAttribute(key: "component", value: "app-lifecycle")
        appStateSpan.setAttribute(key: "ios.app.state", value: appState.rawValue)

        appStateSpan.end(time: time)
    }
}
