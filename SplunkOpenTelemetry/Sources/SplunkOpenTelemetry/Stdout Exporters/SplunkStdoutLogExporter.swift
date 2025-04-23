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

internal import CiscoLogger
import Foundation
import OpenTelemetrySdk

/// Prints Log Record contents into the console using an internal logger.
class SplunkStdoutLogExporter: LogRecordExporter {

    // MARK: - Private

    // Internal Logger
    private let logger = DefaultLogAgent(poolName: "com.splunk.rum", category: "OpenTelemetry")

    // Date format
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

    init() {}

    func export(logRecords: [OpenTelemetrySdk.ReadableLogRecord], explicitTimeout: TimeInterval?) -> OpenTelemetrySdk.ExportResult {
        for logRecord in logRecords {
            // Log LogRecord data
            logger.log {
                var message = ""

                message += "------ 🪵 Log: ------\n"
                message += "Severity: \(String(describing: logRecord.severity))\n"
                message += "Body: \(String(describing: logRecord.body))\n"
                message += "InstrumentationScopeInfo: \(logRecord.instrumentationScopeInfo)\n"
                message += "Timestamp: \(logRecord.timestamp.timeIntervalSince1970.toNanoseconds) (\(logRecord.timestamp.formatted(self.dateFormatStyle)))\n"

                if let observedTimestamp = logRecord.observedTimestamp {
                    message += "ObservedTimestamp: \(observedTimestamp.timeIntervalSince1970.toNanoseconds) (\(observedTimestamp.formatted(self.dateFormatStyle)))\n"
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

        return .success
    }

    func forceFlush(explicitTimeout: TimeInterval?) -> OpenTelemetrySdk.ExportResult {
        return .success
    }

    func shutdown(explicitTimeout: TimeInterval?) {}
}
