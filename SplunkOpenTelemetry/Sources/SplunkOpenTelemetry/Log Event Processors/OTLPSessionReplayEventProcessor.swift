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

internal import CiscoLogger
import Foundation
import OpenTelemetryApi
import OpenTelemetryProtocolExporterCommon
import OpenTelemetrySdk
import SplunkCommon
import SplunkOpenTelemetryBackgroundExporter

/// OTLPSessionReplayEventProcessor sends Session Replay data enriched with Resources via an instantiated background exporter.
///
/// In order to support log record binary body, we bypass processors-exporters chain, to allow exporting log records with binary body.
/// This is achieved by manually creating log records (`SplunkLogRecords`) and sending them to exporter directly.
/// This allows us to use custom types (especially the `AttributeValue` with `Data` field) to send binary body.
///
/// In case the binary body is supported in the future in the upstream, we can revert back to the processors-exporters chain.
public class OTLPSessionReplayEventProcessor: LogEventProcessor {

    // MARK: - Private properties

    private let backgroundLogExporter: OTLPBackgroundHTTPLogExporterBinary

    /// Runtime attributes added manually to each exported log record.
    private unowned let runtimeAttributes: any RuntimeAttributes

    /// Resource object, added to all exported logs manually.
    private let resource: Resource

    /// Print log record contents to standard output if debug is enabled.
    private let debugEnabled: Bool

    /// Internal Logger.
    private let logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "OpenTelemetry")

    /// Date format style for the stdout log.
    private let dateFormatStyle: Date.FormatStyle = .init()
        .month()
        .day()
        .year()
        .hour(.twoDigits(amPM: .wide))
        .minute(.twoDigits)
        .second(.twoDigits)
        .secondFraction(.fractional(3))
        .timeZone(.iso8601(.short))

    /// Logger background dispatch queues.
    private let backgroundQueue = DispatchQueue(
        label: PackageIdentifier.default(named: "SessionReplayEventProcessor"),
        qos: .utility
    )

    // Stored properties for Unit tests.
    #if DEBUG
        public var storedLastProcessedEvent: (any AgentEvent)?
        public var storedLastSentEvent: (any AgentEvent)?
    #endif


    // MARK: - Initialization

    public required init?(
        with sessionReplayEndpoint: URL?,
        resources: AgentResources,
        runtimeAttributes: RuntimeAttributes,
        globalAttributes _: @escaping () -> [String: AttributeValue],
        debugEnabled: Bool
    ) {
        guard let sessionReplayEndpoint else {
            return nil
        }

        let configuration = OtlpConfiguration()
        let envVarHeaders: [(String, String)] = []

        // Initialize background exporter
        backgroundLogExporter = OTLPBackgroundHTTPLogExporterBinary(
            endpoint: sessionReplayEndpoint,
            config: configuration,
            qosConfig: SessionQOSConfiguration(),
            envVarHeaders: envVarHeaders,
            fileType: "replay"
        )

        self.runtimeAttributes = runtimeAttributes
        self.debugEnabled = debugEnabled

        // Session replay specific resource
        let replayResource = Resource(attributes: [
            ResourceAttributes.processRuntimeName.rawValue: .string("mobile"),
            "splunk.rumVersion": .string(resources.agentVersion)
        ])

        // Build Resources
        var resource = Resource()
        resource.merge(with: resources)
        resource.merge(other: replayResource)

        self.resource = resource
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
        }
        else {
            backgroundQueue.async {
                self.processEvent(event: event, completion: completion)
            }
        }
    }


    // MARK: - Private methods

    private func processEvent(event: any AgentEvent, completion: @escaping (Bool) -> Void) {
        // Initialize attribute dictionary
        //
        // As we are bypasing a Log event processor and LogRecordBuilder,
        // we need to add attributes manually.
        var attributes: [String: SplunkAttributeValue] = [:]

        // Merge runtime attributes
        for (key, value) in runtimeAttributes.all {
            if let attributeValue = SplunkAttributeValue(value) {
                attributes[key] = attributeValue
            }
        }

        // Add attributes from the AgentEvent
        // ‼️ This code mirrors code from `LogRecordBuilder+AgentEvent.swift`, but utilizes `SplunkAttributeValue`

        // Attributes - session ID
        if let sessionId = event.sessionId {
            attributes["session.id"] = SplunkAttributeValue(sessionId)
        }

        // Attributes - event.domain
        attributes["event.domain"] = SplunkAttributeValue(event.domain)

        // Attributes - event.name
        attributes["event.name"] = SplunkAttributeValue(event.name)

        // Attributes - component
        attributes["component"] = SplunkAttributeValue(event.component)

        // Merge with provided attributes
        if let providedAttributes = event.attributes {
            for (attributeName, eventAttributeValue) in providedAttributes {
                let splunkAttributeValue = SplunkAttributeValue(eventAttributeValue: eventAttributeValue)
                attributes[attributeName] = splunkAttributeValue
            }
        }

        guard let eventTimestamp = event.timestamp else {
            logger.log(level: .error) {
                "Missing session replay data timestamp."
            }

            return
        }

        // Manually create a Log record
        var logRecord = SplunkReadableLogRecord(
            resource: resource,
            instrumentationScopeInfo: InstrumentationScopeInfo(name: event.instrumentationScope),
            timestamp: eventTimestamp,
            observedTimestamp: Date(),
            attributes: attributes
        )

        // Add body
        if let body = event.body {
            let attributeBody = SplunkAttributeValue(eventAttributeValue: body)
            logRecord.body = attributeBody
        }
        else {
            logger.log(level: .error) {
                "Missing session replay data in the session replay event."
            }
        }

        let logRecords = [logRecord]

        // Export log record
        _ = backgroundLogExporter.export(logRecords: logRecords)

        // Print contents to stdout
        if debugEnabled {
            log(logRecords)
        }

        #if DEBUG
            storedLastSentEvent = event
        #endif

        // TODO: MRUM_AC-1062 (Post GA) - Propagate OTel exporter API errors into the Agent
        DispatchQueue.main.async {
            completion(true)
        }
    }
}

extension OTLPSessionReplayEventProcessor {

    /// Logs a log record to standard output.
    ///
    /// ‼️ This code mirrors `SplunkStdoutLogExporter`.
    private func log(_ logRecords: [SplunkReadableLogRecord]) {
        for logRecord in logRecords {
            let bodyDescription: String

            switch logRecord.body {
            case let .data(data):
                bodyDescription = "\(data.count) bytes"

            default:
                bodyDescription = String(describing: logRecord.body)
            }

            // Log LogRecord data
            logger.log {
                var message = ""

                message += "------ 🪵 Log: ------\n"
                message += "Severity: \(String(describing: logRecord.severity))\n"
                message += "Body: \(bodyDescription)\n"
                message += "InstrumentationScopeInfo: \(logRecord.instrumentationScopeInfo)\n"
                message += "Timestamp: \(logRecord.timestamp.timeIntervalSince1970.toNanoseconds) (\(logRecord.timestamp.formatted(self.dateFormatStyle)))\n"

                if let observedTimestamp = logRecord.observedTimestamp {
                    let observedTimestampNanoseconds = observedTimestamp.timeIntervalSince1970.toNanoseconds
                    let observedTimestampFormatted = observedTimestamp.formatted(self.dateFormatStyle)
                    message += "ObservedTimestamp: \(observedTimestampNanoseconds) (\(observedTimestampFormatted))\n"
                }
                else {
                    message += "ObservedTimestamp: -\n"
                }

                message += "SpanContext: \(String(describing: logRecord.spanContext))\n"

                // Log attributes
                message += "Attributes:\n"
                message += "  \(logRecord.attributes)\n"

                // Log resources
                message += "Resource:\n"
                message += "  \(logRecord.resource.attributes)\n"

                message += "--------------------\n"

                return message
            }
        }
    }
}
