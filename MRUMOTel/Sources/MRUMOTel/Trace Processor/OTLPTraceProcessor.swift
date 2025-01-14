//
//  MRUM SDK, © 2024 CISCO
//

import Foundation
import OpenTelemetryApi
import OpenTelemetryProtocolExporterCommon
import OpenTelemetrySdk
import MRUMSharedProtocols
import MRUMOTelBackgroundExporter

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
