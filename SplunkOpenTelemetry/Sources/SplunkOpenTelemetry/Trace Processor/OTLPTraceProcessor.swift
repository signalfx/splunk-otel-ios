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
import OpenTelemetrySdk
import SplunkCommon
import SplunkOpenTelemetryBackgroundExporter

/// OTLPTraceProcessor initializes and uses OpenTelemetry Trace Provider.
///
/// Traces are enriched by provided Resources and exported via an instantiated background exporter.
public class OTLPTraceProcessor: TraceProcessor {

    // MARK: - Inline types

    private struct InitializationState {
        let tracerProvider: any TracerProvider
        let batchSpanProcessor: OTLPBatchSpanProcessor
    }

    private struct PipelineConfiguration {
        let resources: AgentResources
        let runtimeAttributes: RuntimeAttributes
        let globalAttributes: () -> [String: AttributeValue]
        let debugEnabled: Bool
        let spanInterceptor: SplunkSpanInterceptor?
        let activityTracker: ActivityTracker
    }

    // MARK: - Constants

    private static let crashReportPersistenceTimeout: TimeInterval = 2

    // MARK: - Internal properties

    /// OTel tracer provider shared by direct and log-derived spans.
    let tracerProvider: any TracerProvider


    // MARK: - Private properties

    /// Background exporter for traces (stored to support endpoint updates).
    private let backgroundTraceExporter: any EndpointConfigurableSpanExporter

    /// In-memory batch processor for direct spans.
    private let batchSpanProcessor: OTLPBatchSpanProcessor

    // MARK: - Initialization

    public required init(
        with tracesEndpoint: URL?,
        resources: AgentResources,
        runtimeAttributes: RuntimeAttributes,
        globalAttributes: @escaping () -> [String: AttributeValue],
        debugEnabled: Bool,
        spanInterceptor: SplunkSpanInterceptor?,
        accessToken: String? = nil,
        activityTracker: ActivityTracker
    ) {
        let exporterConfiguration = OTLPExporterConfiguration(agentVersion: resources.agentVersion)
        let envVarHeaders: [(String, String)] = []
        var headers: [String: String] = [:]

        if let accessToken, !accessToken.isEmpty {
            headers["X-SF-Token"] = accessToken
        }

        let backgroundTraceExporter = OTLPBackgroundHTTPTraceExporter(
            endpoint: tracesEndpoint,
            config: exporterConfiguration,
            qosConfig: SessionQOSConfiguration(),
            envVarHeaders: envVarHeaders,
            headers: headers
        )
        let pipelineConfiguration = PipelineConfiguration(
            resources: resources,
            runtimeAttributes: runtimeAttributes,
            globalAttributes: globalAttributes,
            debugEnabled: debugEnabled,
            spanInterceptor: spanInterceptor,
            activityTracker: activityTracker
        )

        let state = Self.makeInitializationState(
            backgroundTraceExporter: backgroundTraceExporter,
            configuration: pipelineConfiguration
        )

        self.backgroundTraceExporter = backgroundTraceExporter
        tracerProvider = state.tracerProvider
        batchSpanProcessor = state.batchSpanProcessor
    }

    init(
        backgroundTraceExporter: any EndpointConfigurableSpanExporter,
        resources: AgentResources,
        runtimeAttributes: RuntimeAttributes,
        globalAttributes: @escaping () -> [String: AttributeValue],
        debugEnabled: Bool,
        spanInterceptor: SplunkSpanInterceptor?,
        activityTracker: ActivityTracker
    ) {
        let pipelineConfiguration = PipelineConfiguration(
            resources: resources,
            runtimeAttributes: runtimeAttributes,
            globalAttributes: globalAttributes,
            debugEnabled: debugEnabled,
            spanInterceptor: spanInterceptor,
            activityTracker: activityTracker
        )
        let state = Self.makeInitializationState(
            backgroundTraceExporter: backgroundTraceExporter,
            configuration: pipelineConfiguration
        )

        self.backgroundTraceExporter = backgroundTraceExporter
        tracerProvider = state.tracerProvider
        batchSpanProcessor = state.batchSpanProcessor
    }

    private static func makeInitializationState(
        backgroundTraceExporter: any EndpointConfigurableSpanExporter,
        configuration: PipelineConfiguration
    ) -> InitializationState {

        // Initialize attribute checker proxy exporter
        // Optionally chain it through stdout exporter
        let attributeCheckerExporter = AttributeCheckerSpanExporter(
            proxy: configuration.debugEnabled
                ? SplunkStdoutSpanExporter(with: backgroundTraceExporter)
                : backgroundTraceExporter
        )

        // Initialize span interceptor proxy exporter
        let spanInterceptorExporter = SpanInterceptorExporter(
            with: configuration.spanInterceptor,
            proxy: attributeCheckerExporter
        )

        // Build Resources
        var resource = Resource()
        resource.merge(with: configuration.resources)

        // Initialize processor
        // Pools ended spans in memory and flushes a batch to the exporter every 0.5s or when
        // 100 spans accumulate, whichever is first (plus on app background/terminate/shutdown).
        let spanProcessor = OTLPBatchSpanProcessor(spanExporter: spanInterceptorExporter)
        let attributesProcessor = OTLPAttributesSpanProcessor(
            with: configuration.runtimeAttributes,
            activityTracker: configuration.activityTracker
        )

        // Global Attributes processor
        let globalAttributesProcessor = OTLPGlobalAttributesSpanProcessor(with: configuration.globalAttributes)

        // Initialize tracer provider
        let tracerProviderBuilder = TracerProviderBuilder()
            .with(resource: resource)
            .add(spanProcessor: globalAttributesProcessor)
            .add(spanProcessor: attributesProcessor)
            .add(spanProcessor: spanProcessor)

        let tracerProvider = tracerProviderBuilder.build()

        // Register default tracer provider
        OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)

        return InitializationState(
            tracerProvider: tracerProvider,
            batchSpanProcessor: spanProcessor
        )
    }

    /// Persists buffered spans before a producer deletes its only source payload.
    package func persistBufferedSpans(completion: @escaping (Bool) -> Void) {
        batchSpanProcessor.persistBufferedSpans(
            timeout: Self.crashReportPersistenceTimeout,
            completion: completion
        )
    }


    // MARK: - Endpoint Management

    /// Immediately updates the endpoint used by subsequent exports.
    ///
    /// - Parameters:
    ///   - newEndpoint: The new endpoint URL.
    ///   - accessToken: Optional access token to use for authentication.
    public func setEndpoint(_ newEndpoint: URL, accessToken: String? = nil) {
        var headers: [String: String] = [:]

        if let accessToken, !accessToken.isEmpty {
            headers["X-SF-Token"] = accessToken
        }

        backgroundTraceExporter.setEndpoint(newEndpoint, headers: headers)
    }

    /// Immediately clears the endpoint so subsequent exports use pending storage.
    public func clearEndpoint() {
        backgroundTraceExporter.clearEndpoint()
    }
}

protocol EndpointConfigurableSpanExporter: SpanExporter {
    func setEndpoint(_ newEndpoint: URL, headers newHeaders: [String: String]?)

    func clearEndpoint()
}

extension OTLPBackgroundHTTPTraceExporter: EndpointConfigurableSpanExporter {}
