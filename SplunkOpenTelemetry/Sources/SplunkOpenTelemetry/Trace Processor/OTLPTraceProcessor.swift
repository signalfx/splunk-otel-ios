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
import StdoutExporter
import ZipkinExporter

/// OTLPTraceProcessor initializes and uses OpenTelemetry Trace Provider.
///
/// Traces are enriched by provided Resources and exported via an instantiated background exporter.
public class OTLPTraceProcessor: TraceProcessor {

    // MARK: - Private properties

    // OTel tracer provider
    private let tracerProvider: TracerProvider


    // MARK: - Initialization

    required public init(with baseURL: URL, resources: AgentResources) {
        /* Using Zipkin for now
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
         */

        // TODO: determine exporter
        let zipkinExportOptions = ZipkinTraceExporterOptions(endpoint: baseURL.absoluteString, serviceName: "myservice")
        let zipkinExporter = ZipkinTraceExporter(options: zipkinExportOptions)
        let spanProcessor = SimpleSpanProcessor(spanExporter: zipkinExporter)

        // TODO: enable/disable based on DEMRUM-1403
        let stdoutExporter = StdoutSpanExporter(isDebug: true)
        let stdoutSpanProcessor = SimpleSpanProcessor(spanExporter: stdoutExporter)


        // Build Resources
        var resource = Resource()
        resource.merge(with: resources)

        // Initialize tracer provider
        tracerProvider = TracerProviderBuilder()
            .with(resource: resource)
            .add(spanProcessor: spanProcessor)
            .add(spanProcessor: stdoutSpanProcessor)
            .build()

        // Register default tracer provider
        OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)
    }


    // MARK: - Events

    /// Sends Span Event to an exporter.
    ///
    /// - Parameters:
    ///   - event: Event to be sent to exporter.
    ///   - completion: Completion block, returns `true` if the event was sent correctly.
    public func sendEvent(event: any Event, completion: @escaping (Bool) -> Void) {
        let tracer = tracerProvider.get(instrumentationName: event.instrumentationScope, instrumentationVersion: nil)

        let name = event.name
        let timestamp = event.timestamp ?? Date()

        var span = tracer.spanBuilder(spanName: name)
            .setStartTime(time: timestamp)
            .startSpan()

        // sessionID
        if let sessionID = event.sessionID {
            span.setAttribute(key: "session.id", value: .string(sessionID))
        }

        // event attributes
        if let eventAttributes = event.attributes {
            for (key, value) in eventAttributes {
                if let spanValue = convertToSpanAttributeValue(value) {
                    span.setAttribute(key: key, value: spanValue)
                } else {
                    span.setAttribute(key: key, value: .string(value.description))
                }
            }
        }

        // event body → attribute „body“ (if exists)
        if let body = event.body {
            let bodyValue = convertToSpanAttributeValue(body) ?? .string(body.description)
            span.setAttribute(key: "body", value: bodyValue)
        }

        span.end(time: timestamp)

        completion(true)
    }


    // MARK: - Private methods

    private func convertToSpanAttributeValue(_ value: EventAttributeValue) -> AttributeValue? {
        switch value {
        case .string(let s):
            return .string(s)
        case .int(let i):
            return .int(i)
        case .double(let d):
            return .double(d)
        case .data(let data):
            return .string(data.base64EncodedString())
        }
    }
}
