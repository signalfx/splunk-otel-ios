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

/// OTLPSessionReplayEventProcessor sends Session Replay data enriched with Resources via an instantiated background exporter.
public class OTLPSessionReplayEventProcessor: LogEventProcessor {

    // MARK: - Private properties

    // OTel log provider
    private let loggerProvider: LoggerProvider

    // Logger background dispatch queues
    private let backgroundQueue = DispatchQueue(
        label: PackageIdentifier.default(named: "SessionReplayEventProcessor"),
        qos: .utility
    )

    // Stored properties for Unit tests
    #if DEBUG
        public var resource: Resource?
        public var storedLastProcessedEvent: (any AgentEvent)?
        public var storedLastSentEvent: (any AgentEvent)?
    #endif


    // MARK: - Initialization

    public required init?(
        with sessionReplayEndpoint: URL?,
        resources: AgentResources,
        runtimeAttributes: RuntimeAttributes,
        globalAttributes: @escaping () -> [String: AttributeValue],
        initialSessionId: String,
        scriptInstanceId: String,
        debugEnabled: Bool
    ) {
        guard let sessionReplayEndpoint else {
            return nil
        }

        let configuration = OtlpConfiguration()
        let envVarHeaders = [(String, String)]()

        // Initialize background exporter
        let backgroundLogExporter = OTLPBackgroundHTTPLogExporter(
            endpoint: sessionReplayEndpoint,
            config: configuration,
            qosConfig: SessionQOSConfiguration(),
            envVarHeaders: envVarHeaders,
            fileType: "replay"
        )

        // Initialize attribute checker proxy exporter
        let attributeCheckerExporter = AttributeCheckerLogExporter(
            proxy: debugEnabled
            ? SplunkStdoutLogExporter(with: backgroundLogExporter)
            : backgroundLogExporter)

        // Initialize LogRecordProcessor
        let simpleLogRecordProcessor = SimpleLogRecordProcessor(
            logRecordExporter: attributeCheckerExporter
        )

        // Initialize AttributesLogRecordProcessor as the first stage of processing,
        // which adds runtime attributes to all processed log records
        let attributesLogRecordProcessor = OTLPAttributesLogRecordProcessor(
            proxy: simpleLogRecordProcessor,
            with: runtimeAttributes
        )

        // Add in Global Attributes processor
        let globalAttributesLogRecordProcessor = OTLPGlobalAttributesLogRecordProcessor(
            proxy: attributesLogRecordProcessor,
            with: globalAttributes
        )

        // Experimental attributes for integration PoC
        let replayResources = Resource(attributes: [
            "process.runtime.name": .string("mobile"),
            "splunk.rumSessionId": .string(initialSessionId),
            "splunk.rumVersion": .string(resources.agentVersion),
            "splunk.scriptInstance": .string(scriptInstanceId)
        ])

        // Build Resources
        var resource = Resource()
        resource.merge(with: resources)
        resource.merge(other: replayResources)

        // Store resources object for Unit tests
        #if DEBUG
            self.resource = resource
        #endif

        let processors: [LogRecordProcessor] = [globalAttributesLogRecordProcessor]

        // Initialize logger provider
        let loggerProviderBuilder = LoggerProviderBuilder()
            .with(processors: processors)
            .with(resource: resource)

        loggerProvider = loggerProviderBuilder.build()
    }


    // MARK: - Events

    public func sendEvent(_ event: any AgentEvent, completion: @escaping (Bool) -> Void) {
        sendEvent(event: event, immediateProcessing: false, completion: completion)
    }

    public func sendEvent(event: any AgentEvent, immediateProcessing: Bool, completion: @escaping (Bool) -> Void) {
        #if DEBUG
            storedLastProcessedEvent = event
        #endif

        if immediateProcessing {
            processEvent(event: event, completion: completion)
        } else {
            backgroundQueue.async {
                self.processEvent(event: event, completion: completion)
            }
        }
    }


    // MARK: - Private methods

    private func processEvent(event: any AgentEvent, completion: @escaping (Bool) -> Void) {
        let logger = loggerProvider.get(instrumentationScopeName: event.instrumentationScope)

        // Build LogRecordBuilder from LogEvent
        let logRecordBuilder = logger
            .logRecordBuilder()
            .build(with: event)

        // Set observation timestamp
        _ = logRecordBuilder.setObservedTimestamp(Date())

        // Send event
        logRecordBuilder.emit()

        #if DEBUG
            storedLastSentEvent = event
        #endif

        // TODO: MRUM_AC-1062 (Post GA) - Propagate OTel exporter API errors into the Agent
        DispatchQueue.main.async {
            completion(true)
        }
    }
}
