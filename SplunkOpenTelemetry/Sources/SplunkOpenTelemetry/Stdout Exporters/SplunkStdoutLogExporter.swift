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
import OpenTelemetrySdk
import SplunkCommon

/// Prints Log Record contents into the console using an internal logger.
class SplunkStdoutLogExporter: LogRecordExporter {

    // MARK: - Private

    private let proxyExporter: LogRecordExporter

    /// Internal Logger.
    private let logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "OpenTelemetry")

    init(with proxy: LogRecordExporter) {
        proxyExporter = proxy
    }

    func export(logRecords: [OpenTelemetrySdk.ReadableLogRecord], explicitTimeout: TimeInterval?) -> OpenTelemetrySdk.ExportResult {
        for logRecord in logRecords {
            // Log LogRecord data
            logger.log {
                var message = ""
                let logRecordTimestampNanoseconds = logRecord.timestamp.timeIntervalSince1970.toNanoseconds

                message += "------ 🪵 Log: ------\n"
                message += "Severity: \(String(describing: logRecord.severity))\n"
                message += "Body: \(String(describing: logRecord.body))\n"
                message += "InstrumentationScopeInfo: \(logRecord.instrumentationScopeInfo)\n"
                message += """
                    Timestamp: \(logRecordTimestampNanoseconds) \
(\(logRecord.timestamp.iso8601Formatted()) / \(logRecord.timestamp.localizedDebugFormatted()))\n
                    """

                if let observedTimestamp = logRecord.observedTimestamp {
                    let observedTimestampNanoseconds = observedTimestamp.timeIntervalSince1970.toNanoseconds
                    message += """
                        ObservedTimestamp: \(observedTimestampNanoseconds) \
(\(observedTimestamp.iso8601Formatted()) / \(observedTimestamp.localizedDebugFormatted()))\n
                        """
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

        return proxyExporter.export(logRecords: logRecords, explicitTimeout: explicitTimeout)
    }

    func forceFlush(explicitTimeout: TimeInterval?) -> OpenTelemetrySdk.ExportResult {
        proxyExporter.forceFlush(explicitTimeout: explicitTimeout)
    }

    func shutdown(explicitTimeout: TimeInterval?) {
        proxyExporter.shutdown(explicitTimeout: explicitTimeout)
    }
}
