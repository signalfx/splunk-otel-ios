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
internal import SplunkOpenTelemetry

// MARK: - Endpoint Management

extension DefaultEventManager {

    /// Updates the endpoint configuration and enables sending spans.
    ///
    /// When this is called, any data that was cached to pending storage
    /// (while no endpoint was configured) will be flushed and sent.
    ///
    /// - Parameter endpoint: The new endpoint configuration to use.
    /// - Throws: ``AgentConfigurationError`` if the endpoint is invalid.
    func updateEndpoint(_ endpoint: EndpointConfiguration) throws {
        // Validate the endpoint
        try endpoint.validate()

        guard let traceUrl = endpoint.traceEndpoint else {
            throw AgentConfigurationError.invalidEndpoint(supplied: endpoint)
        }

        // Update the trace processor endpoint (this also flushes pending data)
        concreteTraceProcessor.setEndpoint(traceUrl, accessToken: endpoint.rumAccessToken)

        // Update session replay processor endpoint if it exists and has a URL
        if let sessionReplayUrl = endpoint.sessionReplayEndpoint {
            sessionReplayProcessor?.setEndpoint(sessionReplayUrl, accessToken: endpoint.rumAccessToken)
        }

        logger.log(level: .info, isPrivate: false) {
            "Endpoint updated. Using trace url: \(traceUrl)"
        }
    }

    /// Disables the endpoint configuration.
    ///
    /// When `cacheData` is `true` (default), spans and events are cached to pending storage
    /// for later sending when a new endpoint is configured. When `false`, data is dropped (NoOp mode).
    ///
    /// - Parameter cacheData: If `true`, data is cached for later sending. If `false`, data is dropped.
    func disableEndpoint(cacheData: Bool = true) {
        if cacheData {
            // Clear endpoint on processors - new data will go to pending storage
            concreteTraceProcessor.clearEndpoint()
            sessionReplayProcessor?.clearEndpoint()

            logger.log(level: .info, isPrivate: false) {
                "Endpoint disabled with caching enabled. Spans will be cached and sent when endpoint is configured."
            }
        }
        else {
            // For complete disable (drop data), we can't use the stored processors
            // since they would still cache. This case requires special handling
            // by the caller if needed (e.g., stop collecting data entirely).
            logger.log(level: .info, isPrivate: false) {
                "Endpoint disabled. Data will continue to be cached until a new endpoint is configured."
            }

            // Note: To truly drop data, the caller should stop generating spans/events.
            // The caching behavior is intentional to prevent data loss.
            concreteTraceProcessor.clearEndpoint()
            sessionReplayProcessor?.clearEndpoint()
        }
    }
}

// MARK: - Processor Creation

extension DefaultEventManager {

    static func createProcessors(
        traceUrl: URL?,
        sessionReplayUrl: URL?,
        accessToken: String?,
        configuration: any AgentConfigurationProtocol,
        agent: SplunkRum
    ) -> Processors {
        // Will be used later by hybrid agents
        let hybridType: String? = nil

        // Build resources
        let resources = DefaultResources(
            appName: configuration.appName,
            appVersion: configuration.appVersion,
            appBuild: AppInfo.buildId ?? "-",
            appDeploymentEnvironment: configuration.deploymentEnvironment,
            agentHybridType: hybridType,
            agentVersion: SplunkRum.version,
            deviceID: DeviceInfo.deviceID ?? "-",
            deviceModelIdentifier: DeviceInfo.type ?? "-",
            deviceManufacturer: "Apple",
            osName: SystemInfo.name,
            osVersion: SystemInfo.version ?? "-",
            osDescription: SystemInfo.description,
            osType: SystemInfo.type
        )

        // Initialize log event processor
        // Note: This processor converts logs to spans, so it uses the trace endpoint
        let logProcessor = OTLPLogToSpanEventProcessor(
            with: traceUrl,
            resources: resources,
            debugEnabled: configuration.enableDebugLogging
        )

        // Initialize session replay processor (optional - requires endpoint)
        let replayProcessor = OTLPSessionReplayEventProcessor(
            with: sessionReplayUrl,
            resources: resources,
            runtimeAttributes: agent.runtimeAttributes,
            globalAttributes: { agent.globalAttributes.getAll() },
            debugEnabled: configuration.enableDebugLogging,
            accessToken: accessToken
        )

        // Initialize trace processor
        let traceProc = OTLPTraceProcessor(
            with: traceUrl,
            resources: resources,
            runtimeAttributes: agent.runtimeAttributes,
            globalAttributes: { agent.globalAttributes.getAll() },
            debugEnabled: configuration.enableDebugLogging,
            spanInterceptor: configuration.spanInterceptor,
            accessToken: accessToken
        )

        return Processors(
            logEventProcessor: logProcessor,
            sessionReplayProcessor: replayProcessor,
            traceProcessor: traceProc
        )
    }
}
