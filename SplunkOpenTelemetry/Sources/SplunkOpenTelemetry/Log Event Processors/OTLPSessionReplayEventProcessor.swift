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

    // Runtime attributes added manually to each exported log record
    private unowned let runtimeAttributes: any RuntimeAttributes

    /// Resource object, added to all exported logs manually.
    private let resource: Resource

    /// Print log record contents to standard output if debug is enabled.
    private let debugEnabled: Bool

    /// Internal Logger.
    private let logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "OpenTelemetry")

    /// Date format style for the stdout log.
    private let dateFormatStyle: Date.FormatStyle = {
        let dateFormat = Date.FormatStyle()
            .month()
            .day()
            .year()
            .hour(.twoDigits(amPM: .wide))
            .minute(.twoDigits)
            .second(.twoDigits)
            .secondFraction(.fractional(3))
            .timeZone(.iso8601(.short))

        return dateFormat
    }()

    /// Logger background dispatch queues.
    private let backgroundQueue = DispatchQueue(
        label: PackageIdentifier.default(named: "SessionReplayEventProcessor"),
        qos: .utility
    )

    // Stored properties for Unit tests
    #if DEBUG
        /// The last event received for processing.
        ///
        /// - Note: This property is available only in `DEBUG` builds and is intended for testing purposes.
        public var storedLastProcessedEvent: (any AgentEvent)?
        /// The last event that was successfully processed and sent.
        ///
        /// - Note: This property is available only in `DEBUG` builds and is intended for testing purposes.
        public var storedLastSentEvent: (any AgentEvent)?
    #endif


    // MARK: - Initialization

    /// Initializes a new session replay event processor.
    ///
    /// This initializer sets up a dedicated background exporter for sending binary session replay data.
    /// It also builds a `Resource` object by merging the provided agent resources with session-replay-specific
    /// attributes like the session ID and script instance ID.
    ///
    /// - Note: This processor bypasses the standard OpenTelemetry processor chain to handle binary payloads directly.
    ///
    /// - Parameters:
    ///   - sessionReplayEndpoint: The URL for the session replay OTLP/HTTP endpoint. If `nil`, initialization fails.
    ///   - resources: A set of static attributes describing the application, device, and OS.
    ///   - runtimeAttributes: An object providing dynamic attributes to be added to each log record.
    ///   - globalAttributes: A closure providing global attributes. This parameter is currently unused.
    ///   - initialSessionId: The initial RUM session ID to associate with the replay data.
    ///   - scriptInstanceId: A unique identifier for the running instance of the session replay script.
    ///   - debugEnabled: A Boolean value that, when `true`, prints the contents of each log record to the console.
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
        backgroundLogExporter = OTLPBackgroundHTTPLogExporterBinary(
            endpoint: sessionReplayEndpoint,
            config: configuration,
            qosConfig: SessionQOSConfiguration(),
            envVarHeaders: envVarHeaders,
            fileType: "replay"
        )

        self.runtimeAttributes = runtimeAttributes
        self.debugEnabled = debugEnabled

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

        self.resource = resource
    }


    // MARK: - Events

    /// Sends a log event for asynchronous processing.
    ///
    /// This method schedules the event to be processed on a background queue.
    ///
    /// - Parameters:
    ///   - event: The `AgentEvent` to be sent.
    ///   - completion: A closure that is called upon completion. The `Bool` value indicates success.
    public func sendEvent(_ event: any AgentEvent, completion: @escaping (Bool) -> Void) {
        sendEvent(event: event, immediateProcessing: false, completion: completion)
    }

    /// Sends a log event, with an option for immediate, synchronous processing.
    ///
    /// This method converts the given `AgentEvent` into a `SplunkReadableLogRecord`, enriches it with
    /// runtime attributes and resources, and exports it.
    ///
    /// - Parameters:
    ///   - event: The `AgentEvent` to be sent.
    ///   - immediateProcessing: If `true`, the event is processed synchronously on the current thread. If `false`, it is processed asynchronously on a background queue.
    ///   - completion: A closure that is called upon completion. The `Bool` value indicates success.
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
        // Initialize attribute dictionary
        //
        // As we are bypasing a Log event processor and LogRecordBuilder,
        // we need to add attributes manually
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

        let eventTimestamp = Date()

        // Manually create a Log record
        var logRecord = SplunkReadableLogRecord(
            resource: resource,
            instrumentationScopeInfo: InstrumentationScopeInfo(name: event.instrumentationScope),
            timestamp: eventTimestamp,
            observedTimestamp: eventTimestamp,
            attributes: attributes
        )

        // Add body
        if let body = event.body {
            let attributeBody = SplunkAttributeValue(eventAttributeValue: body)
            logRecord.body = attributeBody
        } else {
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
                } else {
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
