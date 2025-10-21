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
import OpenTelemetrySdk
import SplunkCommon

/// Prints Log Record contents into the console using an internal logger.
class SplunkStdoutLogExporter: LogRecordExporter {

    // MARK: - Private Properties

    private let proxyExporter: LogRecordExporter
    private let logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "OpenTelemetry")

    // Date formatters; one for modern iOS 15+ and a fallback for older versions.
    private var dateFormatStyle: Any?
    private var legacyDateFormatter: DateFormatter?

    // MARK: - Initialization

    init(with proxy: LogRecordExporter) {
        proxyExporter = proxy

        if #available(iOS 15.0, tvOS 15.0, *) {
            let style: Date.FormatStyle = .init()
                .month()
                .day()
                .year()
                .hour(.twoDigits(amPM: .wide))
                .minute(.twoDigits)
                .second(.twoDigits)
                .secondFraction(.fractional(3))
                .timeZone(.iso8601(.short))
            self.dateFormatStyle = style
        }
        else {
            // Fallback for iOS 13 & 14
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd/yyyy, hh:mm:ss.SSS a Z"
            legacyDateFormatter = formatter
        }
    }

    // MARK: - LogRecordExporter

    func export(logRecords: [OpenTelemetrySdk.ReadableLogRecord], explicitTimeout: TimeInterval?) -> OpenTelemetrySdk.ExportResult {
        for logRecord in logRecords {
            logger.log { self.formatLogRecordMessage(logRecord) }
        }

        return proxyExporter.export(logRecords: logRecords, explicitTimeout: explicitTimeout)
    }

    func forceFlush(explicitTimeout: TimeInterval?) -> OpenTelemetrySdk.ExportResult {
        proxyExporter.forceFlush(explicitTimeout: explicitTimeout)
    }

    func shutdown(explicitTimeout: TimeInterval?) {
        proxyExporter.shutdown(explicitTimeout: explicitTimeout)
    }

    // MARK: - Private Helpers

    private func formatLogRecordMessage(_ logRecord: ReadableLogRecord) -> String {
        var message = ""

        message += "------ 🪵 Log: ------\n"
        message += "Severity: \(String(describing: logRecord.severity))\n"
        message += "Body: \(String(describing: logRecord.body))\n"
        message += "InstrumentationScopeInfo: \(logRecord.instrumentationScopeInfo)\n"

        if #available(iOS 15.0, tvOS 15.0, *), let style = dateFormatStyle as? Date.FormatStyle {
            message += "Timestamp: \(logRecord.timestamp.timeIntervalSince1970.toNanoseconds) (\(logRecord.timestamp.formatted(style)))\n"

            if let observedTimestamp = logRecord.observedTimestamp {
                let observedTimestampNanoseconds = observedTimestamp.timeIntervalSince1970.toNanoseconds
                let observedTimestampFormatted = observedTimestamp.formatted(style)
                message += "ObservedTimestamp: \(observedTimestampNanoseconds) (\(observedTimestampFormatted))\n"
            }
            else {
                message += "ObservedTimestamp: -\n"
            }
        }
        else if let formatter = legacyDateFormatter {
            message += "Timestamp: \(logRecord.timestamp.timeIntervalSince1970.toNanoseconds) (\(formatter.string(from: logRecord.timestamp)))\n"

            if let observedTimestamp = logRecord.observedTimestamp {
                let observedTimestampNanoseconds = observedTimestamp.timeIntervalSince1970.toNanoseconds
                let observedTimestampFormatted = formatter.string(from: observedTimestamp)
                message += "ObservedTimestamp: \(observedTimestampNanoseconds) (\(observedTimestampFormatted))\n"
            }
            else {
                message += "ObservedTimestamp: -\n"
            }
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
