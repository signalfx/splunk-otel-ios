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
import OpenTelemetryProtocolExporterCommon
import OpenTelemetrySdk
import SplunkCommon
import SplunkOpenTelemetryBackgroundExporter

/// OTLPTraceProcessor initializes and uses OpenTelemetry Trace Provider.
///
/// Traces are enriched by provided Resources and exported via an instantiated background exporter.
public class OTLPTraceProcessor: TraceProcessor {

    // MARK: - Private properties

    // OTel tracer provider
    private let tracerProvider: TracerProvider


    // MARK: - Initialization

    public required init(
        with tracesEndpoint: URL,
        resources: AgentResources,
        runtimeAttributes: RuntimeAttributes,
        globalAttributes: @escaping () -> [String: AttributeValue],
        debugEnabled: Bool,
        spanInterceptor: SplunkSpanInterceptor?
    ) {

        let configuration = OtlpConfiguration()
        let envVarHeaders = [(String, String)]()

        // Initialize background exporter
        let backgroundTraceExporter = OTLPBackgroundHTTPTraceExporter(
            endpoint: tracesEndpoint,
            config: configuration,
            qosConfig: SessionQOSConfiguration(),
            envVarHeaders: envVarHeaders
        )

        // Initialize attribute checker proxy exporter
        // Optionally chain it through stdout exporter
        let attributeCheckerExporter = AttributeCheckerSpanExporter(
            proxy: debugEnabled
                ? SplunkStdoutSpanExporter(with: backgroundTraceExporter)
                : backgroundTraceExporter)

        // Initialize span interceptor proxy exporter
        let spanInterceptorExporter = SpanInterceptorExporter(
            with: spanInterceptor,
            proxy: attributeCheckerExporter
        )

        // Initialize processor
        let spanProcessor = SimpleSpanProcessor(spanExporter: spanInterceptorExporter)
        let attributesProcessor = OLTPAttributesSpanProcessor(with: runtimeAttributes)

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

        self.tracerProvider = tracerProvider
    }
}
