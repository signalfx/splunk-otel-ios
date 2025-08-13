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

/// An exporter that transforms OpenTelemetry `ReadableLogRecord` instances into `Span` instances.
///
/// This class is a key component of the "log-to-span" architecture. It receives log records,
/// creates a new span for each one using the global `TracerProvider`, and copies the log's
/// attributes and body to the span. The span is started and ended immediately with the log's timestamp.
public class OTLPLogToSpanExporter: LogRecordExporter {

    // MARK: - Private properties

    private let agentVersion: String

    /// Internal Logger.
    private let logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "Log to Span Exporter")


    // MARK: - Initialization

    init(agentVersion: String) {
        self.agentVersion = agentVersion
    }


    // MARK: - LogRecordExporter protocol implementation

    /// Transforms and exports a batch of log records as spans.
    ///
    /// For each log record in the batch, this method creates a new span, sets its name based on the
    /// log's `event.name` attribute, copies all attributes, and sets the log's body as a span attribute.
    /// The span's start and end time are set to the log's timestamp.
    ///
    /// - Parameters:
    ///   - logRecords: An array of `ReadableLogRecord` to be exported.
    ///   - explicitTimeout: This parameter is ignored as the export is synchronous.
    /// - Returns: Always returns `.success` as there is no remote endpoint to fail.
    public func export(logRecords: [OpenTelemetrySdk.ReadableLogRecord], explicitTimeout: TimeInterval?) -> OpenTelemetrySdk.ExportResult {

        let tracer = OpenTelemetry.instance
            .tracerProvider
            .get(
                instrumentationName: "LogToSpan",
                instrumentationVersion: agentVersion
            )

        for log in logRecords {

            guard
                let spanName = spanName(from: log),
                !spanName.isEmpty
            else {
                logger.log(level: .error) {
                    "Missing span name for log record"
                }
                continue
            }

            let span = tracer
                .spanBuilder(spanName: spanName)
                .setStartTime(time: log.timestamp)
                .startSpan()

            for (key, value) in log.attributes {
                span.setAttribute(key: key, value: value)
            }

            span.setAttribute(key: "body", value: log.body)

            span.end(time: log.timestamp)
        }
        return .success
    }

    private func spanName(from log: ReadableLogRecord) -> String? {
        // Check for `eventName` property first
        // ‼️ uncomment once the `eventName` log record attribute is implemented
        // https://github.com/open-telemetry/opentelemetry-specification/blob/v1.45.0/specification/logs/data-model.md#field-eventname
        /*
        if let eventName = log.eventName {
            return eventName
        } else
         */
        // Then check for `event.name` attribute
        if let eventName = log.attributes[OpenTelemetryApi.SemanticAttributes.eventName.rawValue]?.description {
            return eventName
        }

        // Add a defalt span name for all other logs
        return "splunk.log"
    }

    /// Performs a no-op shutdown.
    ///
    /// This exporter is stateless and does not require any cleanup.
    /// - Parameter explicitTimeout: This parameter is ignored.
    public func shutdown(explicitTimeout: TimeInterval?) {}

    /// Performs a no-op flush and returns a success result.
    ///
    /// Since logs are converted to spans immediately upon export, there is no internal buffer to flush.
    /// - Parameter explicitTimeout: This parameter is ignored.
    /// - Returns: Always returns `.success`.
    public func forceFlush(explicitTimeout: TimeInterval?) -> OpenTelemetrySdk.ExportResult {
        return .success
    }
}
