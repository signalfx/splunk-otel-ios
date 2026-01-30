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

    /// The URL used when caching is enabled but no endpoint is configured.
    ///
    /// This non-routable address forces the exporter to cache data to disk.
    static let cachingUrl = URL(string: "https://0.0.0.0:0/v1/traces")

    /// Updates the endpoint configuration and reinitializes processors to start sending spans.
    ///
    /// - Parameter endpoint: The new endpoint configuration to use.
    /// - Throws: ``AgentConfigurationError`` if the endpoint is invalid.
    func updateEndpoint(_ endpoint: EndpointConfiguration) throws {
        // Validate the endpoint
        try endpoint.validate()

        guard let traceUrl = endpoint.traceEndpoint else {
            throw AgentConfigurationError.invalidEndpoint(supplied: endpoint)
        }

        // Create new processors with the updated endpoint
        let processors = Self.createProcessors(
            traceUrl: traceUrl,
            sessionReplayUrl: endpoint.sessionReplayEndpoint,
            accessToken: endpoint.rumAccessToken,
            configuration: configuration,
            agent: agent
        )

        // Replace processors
        logEventProcessor = processors.logEventProcessor
        sessionReplayProcessor = processors.sessionReplayProcessor
        traceProcessor = processors.traceProcessor

        logger.log(level: .info, isPrivate: false) {
            "Endpoint updated. Using trace url: \(traceUrl)"
        }
    }

    /// Disables the endpoint configuration.
    ///
    /// When `cacheData` is `true` (default), spans and events are cached to disk for later sending
    /// when a new endpoint is configured. When `false`, data is dropped (NoOp mode).
    ///
    /// - Parameter cacheData: If `true`, data is cached for later sending. If `false`, data is dropped.
    func disableEndpoint(cacheData: Bool = true) {
        if cacheData, let cachingUrl = Self.cachingUrl {
            // Keep real processors active for caching - they'll write to disk
            // but HTTP will fail to a non-routable address, triggering retry cache
            let processors = Self.createProcessors(
                traceUrl: cachingUrl,
                sessionReplayUrl: nil,
                accessToken: nil,
                configuration: configuration,
                agent: agent
            )

            logEventProcessor = processors.logEventProcessor
            sessionReplayProcessor = processors.sessionReplayProcessor
            traceProcessor = processors.traceProcessor

            logger.log(level: .info, isPrivate: false) {
                "Endpoint disabled with caching enabled. Spans will be cached and sent when endpoint is configured."
            }
        }
        else {
            disableEndpointWithNoOp()
        }
    }

    /// Disables the endpoint with NoOp processors (data is dropped).
    func disableEndpointWithNoOp() {
        logEventProcessor = NoOpLogEventProcessor()
        sessionReplayProcessor = nil
        traceProcessor = NoOpTraceProcessor()

        logger.log(level: .info, isPrivate: false) {
            "Endpoint disabled. Spans will not be sent until endpoint is configured."
        }
    }
}

// MARK: - Processor Creation

extension DefaultEventManager {

    static func createProcessors(
        traceUrl: URL,
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
        let logProcessor = OTLPLogToSpanEventProcessor(
            with: traceUrl,
            resources: resources,
            debugEnabled: configuration.enableDebugLogging
        )

        // Initialize session replay processor (optional)
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
