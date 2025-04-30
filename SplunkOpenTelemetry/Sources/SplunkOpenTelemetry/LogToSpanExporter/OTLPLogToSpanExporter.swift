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
import OpenTelemetryProtocolExporterCommon
import OpenTelemetrySdk
import OpenTelemetryApi
import SplunkCommon

public class OTLPLogToSpanExporter: LogRecordExporter {

    // MARK: - Private properties

    private let agentVersion: String

    // Internal Logger
    private let logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "Log to Span Exporter")


    // MARK: - Initialization

    init(agentVersion: String) {
        self.agentVersion = agentVersion
    }


    // MARK: - LogRecordExporter protocol implementation

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
        return log.attributes["event.name"]?.description
    }

    public func shutdown(explicitTimeout: TimeInterval?) {}

    public func forceFlush(explicitTimeout: TimeInterval?) -> OpenTelemetrySdk.ExportResult {
        return .success
    }
}
