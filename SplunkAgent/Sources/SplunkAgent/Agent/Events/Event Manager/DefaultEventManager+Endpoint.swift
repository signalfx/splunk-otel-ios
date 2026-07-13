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

    /// Registers the direct-span terminal drain that runs after AppState emits its terminate span.
    func registerTraceTerminationDrain() {
        concreteTraceProcessor.registerTerminationObserver()
    }

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

        // Replace semantics: the new config fully replaces the old one.
        // If a session replay URL is provided, activate the processor (also flushes pending data).
        // If omitted, switch the processor to pending mode so cached data can be sent later.
        if let sessionReplayUrl = endpoint.sessionReplayEndpoint {
            sessionReplayProcessor.setEndpoint(sessionReplayUrl, accessToken: endpoint.rumAccessToken)
        }
        else {
            sessionReplayProcessor.clearEndpoint()
        }

        logger.log(level: .info, isPrivate: false) {
            "Endpoint updated. Using trace url: \(traceUrl)"
        }
    }

    /// Disables the endpoint configuration.
    ///
    /// Data is cached to pending storage for later sending when a new endpoint is configured.
    func disableEndpoint() {
        concreteTraceProcessor.clearEndpoint()
        sessionReplayProcessor.clearEndpoint()

        logger.log(level: .info, isPrivate: false) {
            "Endpoint disabled. Spans will be cached and sent when endpoint is configured."
        }
    }
}

// MARK: - Processor Creation

extension DefaultEventManager {

    static func createSessionReplayProcessor(
        sessionReplayUrl: URL?,
        accessToken: String?,
        configuration: any AgentConfigurationProtocol,
        agent: SplunkRum
    ) -> OTLPSessionReplayEventProcessor {
        let resources = buildResources(configuration: configuration)

        return OTLPSessionReplayEventProcessor(
            with: sessionReplayUrl,
            resources: resources,
            runtimeAttributes: agent.runtimeAttributes,
            globalAttributes: { agent.globalAttributes.getAll() },
            debugEnabled: configuration.enableDebugLogging,
            accessToken: accessToken
        )
    }

    static func createProcessors(
        traceUrl: URL?,
        sessionReplayUrl: URL?,
        accessToken: String?,
        configuration: any AgentConfigurationProtocol,
        agent: SplunkRum
    ) -> Processors {
        let resources = buildResources(configuration: configuration)

        // Initialize session replay processor (operates in pending mode when endpoint is nil)
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
            accessToken: accessToken,
            activityTracker: agent.currentSession
        )

        // Initialize log event processor.
        // Note: This processor converts logs to spans, so it uses the trace endpoint. It bypasses
        // the direct-span memory batch so crash/custom/internal events are persisted before
        // log export reports success.
        let logProcessor = OTLPLogToSpanEventProcessor(
            with: traceUrl,
            resources: resources,
            debugEnabled: configuration.enableDebugLogging,
            traceProcessor: traceProc
        )

        return Processors(
            logEventProcessor: logProcessor,
            sessionReplayProcessor: replayProcessor,
            traceProcessor: traceProc
        )
    }

    private static func buildResources(configuration: any AgentConfigurationProtocol) -> DefaultResources {
        // Will be used later by hybrid agents
        let hybridType: String? = nil

        return DefaultResources(
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
    }
}
