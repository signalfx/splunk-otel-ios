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
import SplunkLogger

/// OTLPLogEventProcessor sends OpenTelemetry Logs enriched with Resources via an instantiated background exporter.
public class OTLPLogEventProcessor: LogEventProcessor {

    // MARK: - Private properties

    // OTel logger provider
    private let loggerProvider: LoggerProvider

    // Internal Logger
    private let internalLogger = InternalLogger(configuration: .default(subsystem: "Splunk RUM OTel", category: "Logs"))

    // Logger background dispatch queues
    private let backgroundQueue = DispatchQueue(label: "com.splunk.rum.LogEventProcessor", qos: .utility)

    // Stored properties for Unit tests
#if DEBUG
    public var resource: Resource?
    public var storedLastProcessedEvent: (any AgentEvent)?
    public var storedLastSentEvent: (any AgentEvent)?
#endif


    // MARK: - Initialization
    
    required public init(with logsEndpoint: URL, resources: AgentResources, debugEnabled: Bool) {

        let configuration = OtlpConfiguration()
        let envVarHeaders = [(String, String)]()

        // Initialize background exporter
        let backgroundLogExporter = OTLPBackgroundHTTPLogExporter(
            endpoint: logsEndpoint,
            config: configuration,
            qosConfig: SessionQOSConfiguration(),
            envVarHeaders: envVarHeaders
        )

        // Initialise LogRecordProcessor
        let simpleLogRecordProcessor = SimpleLogRecordProcessor(logRecordExporter: backgroundLogExporter)

        // Build Resources
        var resource = Resource()
        resource.merge(with: resources)

        // Store resources object for Unit tests
        #if DEBUG
        self.resource = resource
        #endif

        var processors: [LogRecordProcessor] = [simpleLogRecordProcessor]

        // Initialize optional stdout exporter
        if debugEnabled {
            let stdoutExporter = SplunkStdoutLogExporter()
            let stdoutSpanProcessor = SimpleLogRecordProcessor(logRecordExporter: stdoutExporter)

            processors.append(stdoutSpanProcessor)
        }

        // Initialize logger provider
        let loggerProviderBuilder = LoggerProviderBuilder()
            .with(processors: processors)
            .with(resource: resource)

        let loggerProvider = loggerProviderBuilder.build()
        
        // Set default logger provider
        OpenTelemetry.registerLoggerProvider(loggerProvider: loggerProvider)

        self.loggerProvider = loggerProvider
    }


    // MARK: - Events

    public func sendEvent(_ event: any AgentEvent, completion: @escaping (Bool) -> Void) {
        sendEvent(event: event, immediateProcessing: false, completion: completion)
    }

    public func sendEvent(event: any AgentEvent, immediateProcessing: Bool , completion: @escaping (Bool) -> Void) {
#if DEBUG
        storedLastProcessedEvent = event
#endif

        if immediateProcessing {
            self.processEvent(event: event, completion: completion)
        } else {
            backgroundQueue.async {
                self.processEvent(event: event, completion: completion)
            }
        }
    }


    // MARK: - Private methods

    private func processEvent(event: any AgentEvent, completion: @escaping (Bool) -> Void) {
        let logger = self.loggerProvider.get(instrumentationScopeName: event.instrumentationScope)

        // Build LogRecordBuilder from LogEvent
        var logRecordBuilder = logger.logRecordBuilder()
        logRecordBuilder = self.buildEvent(with: event, logRecordBuilder: logRecordBuilder)

        // Set observation timestamp
        _ = logRecordBuilder.setObservedTimestamp(Date())

        // Send event
        logRecordBuilder.emit()

#if DEBUG
        self.storedLastSentEvent = event
#endif

        // TODO: MRUM_AC-1062 (Post GA) - Propagate OTel exporter API errors into the Agent
        DispatchQueue.main.async {
            completion(true)
        }
    }
}
