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
import OpenTelemetryProtocolExporterCommon
import OpenTelemetrySdk
import SplunkSharedProtocols
import SplunkOpenTelemetryBackgroundExporter

/// OTLPTraceProcessor initializes and uses OpenTelemetry Trace Provider.
///
/// Traces are enriched by provided Resources and exported via an instantiated background exporter.
public class OTLPTraceProcessor: TraceProcessor {

    // MARK: - Private properties

    // OTel tracer provider
    private let tracerProvider: TracerProvider
    
    
    // MARK: - Initialization
    
    required public init(with baseURL: URL, resources: AgentResources) {
        let configuration = OtlpConfiguration()
        let envVarHeaders = [(String, String)]()

        // Construct traces api endpoint from user supplied vanity url and traces api path
        let tracesEndpoint = baseURL.appendingPathComponent(ApiPaths.traces.rawValue)

        // Initialise background exporter
        let backgroundTraceExporter = OTLPBackgroundHTTPTraceExporter(
            endpoint: tracesEndpoint,
            config: configuration,
            qosConfig: SessionQOSConfiguration(),
            envVarHeaders: envVarHeaders
        )
                
        // Initialise processor
        let spanProcessor = SimpleSpanProcessor(spanExporter: backgroundTraceExporter)
        
        // Build Resources
        var resource = Resource()
        resource.merge(with: resources)
        
        // Initialize tracer provider
        tracerProvider = TracerProviderBuilder()
            .with(resource: resource)
            .add(spanProcessor: spanProcessor)
            .build()
        
        // Register default tracer provider
        OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)
    }
}
