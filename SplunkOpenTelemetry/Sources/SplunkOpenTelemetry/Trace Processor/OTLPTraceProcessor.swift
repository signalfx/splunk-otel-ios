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

    // MARK: - Private properties

    /// OTel tracer provider.
    private let tracerProvider: TracerProviderSdk

    /// Batch processor retained for persistence-only lifecycle drains.
    private let batchSpanProcessor: OTLPBatchSpanProcessor

    /// Background exporter for traces (stored to support endpoint updates).
    private let backgroundTraceExporter: OTLPBackgroundHTTPTraceExporter


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

        let configuration = OTLPExporterConfiguration(agentVersion: resources.agentVersion)
        let envVarHeaders: [(String, String)] = []
        var headers: [String: String] = [:]

        if let accessToken, !accessToken.isEmpty {
            headers["X-SF-Token"] = accessToken
        }

        // Initialize background exporter
        backgroundTraceExporter = OTLPBackgroundHTTPTraceExporter(
            endpoint: tracesEndpoint,
            config: configuration,
            qosConfig: SessionQOSConfiguration(),
            envVarHeaders: envVarHeaders,
            headers: headers
        )

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

        // Initialize processor
        let spanProcessor = OTLPBatchSpanProcessor(
            spanExporter: spanInterceptorExporter,
            configuration: .production(exportTimeout: configuration.timeout)
        )
        let attributesProcessor = OTLPAttributesSpanProcessor(
            with: runtimeAttributes,
            activityTracker: activityTracker
        )

        // Global Attributes processor
        let globalAttributesProcessor = OTLPGlobalAttributesSpanProcessor(with: globalAttributes)

        // Build Resources
        var resource = Resource()
        resource.merge(with: resources)

        // Initialize tracer provider
        let tracerProviderBuilder = TracerProviderBuilder()
            .with(resource: resource)
            .add(spanProcessor: globalAttributesProcessor)
            .add(spanProcessor: attributesProcessor)
            .add(spanProcessor: spanProcessor)

        let tracerProvider = tracerProviderBuilder.build()

        // Register default tracer provider
        OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)

        batchSpanProcessor = spanProcessor
        self.tracerProvider = tracerProvider
    }


    // MARK: - Export lifecycle

    /// Persists all spans currently waiting in the in-memory export batch.
    public func forceFlush(timeout: TimeInterval? = nil) {
        tracerProvider.forceFlush(timeout: timeout)
    }

    /// Persists spans waiting in memory without waiting for background URL session work.
    ///
    /// - Parameter timeout: Maximum duration passed to each persistence export operation.
    public func persistPendingSpans(timeout: TimeInterval? = nil) {
        batchSpanProcessor.persistPendingSpans(timeout: timeout)
    }


    // MARK: - Endpoint Management

    /// Updates the endpoint and flushes any pending data.
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

    /// Clears the endpoint, causing new data to be cached to pending storage.
    public func clearEndpoint() {
        backgroundTraceExporter.clearEndpoint()
    }
}
