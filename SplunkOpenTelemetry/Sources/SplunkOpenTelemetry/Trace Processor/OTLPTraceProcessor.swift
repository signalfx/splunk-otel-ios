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

    // MARK: - Internal properties

    /// OTel tracer provider shared by direct and log-derived spans.
    let tracerProvider: any TracerProvider


    // MARK: - Private properties

    /// Background exporter for traces (stored to support endpoint updates).
    private let backgroundTraceExporter: any EndpointConfigurableSpanExporter

    /// In-memory batch processor for direct spans.
    private let batchSpanProcessor: OTLPBatchSpanProcessor

    // MARK: - Initialization

    public required convenience init(
        with tracesEndpoint: URL?,
        resources: AgentResources,
        runtimeAttributes: RuntimeAttributes,
        globalAttributes: @escaping () -> [String: AttributeValue],
        debugEnabled: Bool,
        spanInterceptor: SplunkSpanInterceptor?,
        accessToken: String? = nil,
        activityTracker: ActivityTracker
    ) {
        let configuration = OTLPExporterConfiguration(agentVersion: resources.agentVersion)
        let envVarHeaders: [(String, String)] = []
        var headers: [String: String] = [:]

        if let accessToken, !accessToken.isEmpty {
            headers["X-SF-Token"] = accessToken
        }

        let backgroundTraceExporter = OTLPBackgroundHTTPTraceExporter(
            endpoint: tracesEndpoint,
            config: configuration,
            qosConfig: SessionQOSConfiguration(),
            envVarHeaders: envVarHeaders,
            headers: headers
        )

        self.init(
            backgroundTraceExporter: backgroundTraceExporter,
            resources: resources,
            runtimeAttributes: runtimeAttributes,
            globalAttributes: globalAttributes,
            debugEnabled: debugEnabled,
            spanInterceptor: spanInterceptor,
            activityTracker: activityTracker
        )
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
        self.backgroundTraceExporter = backgroundTraceExporter

        // Initialize attribute checker proxy exporter
        // Optionally chain it through stdout exporter
        let attributeCheckerExporter = AttributeCheckerSpanExporter(
            proxy: debugEnabled
                ? SplunkStdoutSpanExporter(with: backgroundTraceExporter)
                : backgroundTraceExporter
        )

        // Initialize span interceptor proxy exporter
        let spanInterceptorExporter = SpanInterceptorExporter(
            with: spanInterceptor,
            proxy: attributeCheckerExporter
        )

        // Build Resources
        var resource = Resource()
        resource.merge(with: resources)

        // Initialize processor
        // Pools ended spans in memory and flushes a batch to the exporter every 0.5s or when
        // 100 spans accumulate, whichever is first (plus on app background/terminate/shutdown).
        let spanProcessor = OTLPBatchSpanProcessor(spanExporter: spanInterceptorExporter)
        let attributesProcessor = OTLPAttributesSpanProcessor(
            with: runtimeAttributes,
            activityTracker: activityTracker
        )

        // Global Attributes processor
        let globalAttributesProcessor = OTLPGlobalAttributesSpanProcessor(with: globalAttributes)

        // Initialize tracer provider
        let tracerProviderBuilder = TracerProviderBuilder()
            .with(resource: resource)
            .add(spanProcessor: globalAttributesProcessor)
            .add(spanProcessor: attributesProcessor)
            .add(spanProcessor: spanProcessor)

        let tracerProvider = tracerProviderBuilder.build()

        // Register default tracer provider
        OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)

        self.tracerProvider = tracerProvider
        batchSpanProcessor = spanProcessor
    }


    // MARK: - Lifecycle

    /// Registers the direct-span background drain triggered after asynchronous producers flush their spans.
    package func registerBackgroundObserver(prepareForBackground: @escaping () async -> Void) {
        batchSpanProcessor.registerBackgroundObserver(prepareForBackground: prepareForBackground)
    }

    /// Registers the direct-span termination drain triggered after terminal producers flush their spans.
    ///
    /// The handler gives known terminal producers a chance to synchronously enqueue their direct spans,
    /// then blocks for a short bounded drain when `willTerminate` is delivered.
    package func registerTerminationObserver(prepareForTermination: @escaping () async -> Void) {
        batchSpanProcessor.registerTerminationObserver(prepareForTermination: prepareForTermination)
    }


    // MARK: - Endpoint Management

    /// Immediately updates the endpoint used by subsequent exports.
    ///
    /// - Parameters:
    ///   - newEndpoint: The new endpoint URL.
    ///   - accessToken: Optional access token to use for authentication.
    package func setEndpoint(_ newEndpoint: URL, accessToken: String? = nil) {
        var headers: [String: String] = [:]

        if let accessToken, !accessToken.isEmpty {
            headers["X-SF-Token"] = accessToken
        }

        backgroundTraceExporter.setEndpoint(newEndpoint, headers: headers)
    }

    /// Immediately clears the endpoint so subsequent exports use pending storage.
    package func clearEndpoint() {
        backgroundTraceExporter.clearEndpoint()
    }
}

protocol EndpointConfigurableSpanExporter: SpanExporter {
    func setEndpoint(_ newEndpoint: URL, headers newHeaders: [String: String]?)

    func clearEndpoint()
}

extension OTLPBackgroundHTTPTraceExporter: EndpointConfigurableSpanExporter {}
