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
internal import OpenTelemetryApi
@_spi(SplunkInternal) import SplunkCommon

/// Creates and sends an OpenTelemetry span from supplied network monitor data.
struct OTelDestination: NetworkMonitorDestination {

    // MARK: - Sending

    /// Sends a network event as an OpenTelemetry span.
    ///
    /// - Parameters:
    ///   - networkEvent: The network change event to send as a span
    ///   - sharedState: The agent's shared state, used for agent version information
    func send(networkEvent: NetworkMonitorEvent, sharedState: (any AgentSharedState)?) {
        let tracer = OpenTelemetry.instance
            .tracerProvider
            .get(
                instrumentationName: NetworkMonitorSpanAttributes.instrumentationName,
                instrumentationVersion: sharedState?.agentVersion
            )

        let span = tracer.spanBuilder(spanName: NetworkMonitorSpanAttributes.spanName)
            .setStartTime(time: networkEvent.timestamp)
            .startSpan()

        let status =
            networkEvent.isConnected
                ? NetworkMonitorSpanAttributes.statusValueAvailable
                : NetworkMonitorSpanAttributes.statusValueLost

        span.clearAndSetAttribute(key: NetworkMonitorSpanAttributes.networkStatus, value: status)
        span.clearAndSetAttribute(
            key: SemanticConventions.Network.connectionType,
            value: networkEvent.connectionType.rawValue
        )
        if let radioType = networkEvent.radioType {
            span.clearAndSetAttribute(key: SemanticConventions.Network.connectionSubtype, value: radioType)
        }

        span.end(time: networkEvent.timestamp)
    }
}
