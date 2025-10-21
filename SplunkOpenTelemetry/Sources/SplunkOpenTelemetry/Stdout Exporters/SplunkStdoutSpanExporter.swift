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

/// Prints Span contents into the console using an internal logger.
class SplunkStdoutSpanExporter: SpanExporter {

    // MARK: - Private

    private let proxyExporter: SpanExporter

    /// Internal Logger.
    private let logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "OpenTelemetry")

    /// Date format.
    private var dateFormatStyle: Any?
    private var legacyDateFormatter: DateFormatter?

    init(with proxy: SpanExporter) {
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
            dateFormatStyle = style
        }
        else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd/yyyy, hh:mm:ss.SSS a Z"
            legacyDateFormatter = formatter
        }
    }

    func export(spans: [SpanData], explicitTimeout _: TimeInterval?) -> SpanExporterResultCode {
        for span in spans {
            // Log Span data
            logger.log {
                var message = ""

                message += "------ 🔧 Span: ------\n"
                message += "Span: \(span.name)\n"
                message += "TraceId: \(span.traceId.hexString)\n"
                message += "SpanId: \(span.spanId.hexString)\n"
                message += "Span kind: \(span.kind.rawValue)\n"
                message += "TraceFlags: \(span.traceFlags)\n"
                message += "TraceState: \(span.traceState)\n"
                message += "ParentSpanId: \(span.parentSpanId?.hexString ?? "-")\n"

                if #available(iOS 15.0, tvOS 15.0, *), let style = self.dateFormatStyle as? Date.FormatStyle {
                    message += "Start: \(span.startTime.timeIntervalSince1970.toNanoseconds) (\(span.startTime.formatted(style)))\n"
                    message += "End: \(span.endTime.timeIntervalSince1970.toNanoseconds) (\(span.endTime.formatted(style)))\n"
                }
                else if let formatter = self.legacyDateFormatter {
                    message += "Start: \(span.startTime.timeIntervalSince1970.toNanoseconds) (\(formatter.string(from: span.startTime)))\n"
                    message += "End: \(span.endTime.timeIntervalSince1970.toNanoseconds) (\(formatter.string(from: span.endTime)))\n"
                }

                let duration = span.endTime.timeIntervalSince(span.startTime)
                message += "Duration: \(duration.toNanoseconds) nanoseconds (\(duration) seconds)\n"

                // Log attributes
                message += "Attributes:\n"
                message += "  \(span.attributes)\n"

                // Log resources
                message += "Resource:\n"
                message += "  \(span.resource.attributes)\n"

                // Log span events
                if !span.events.isEmpty {
                    message += "Span events:\n"

                    for event in span.events {
                        let ts = event.timestamp.timeIntervalSince(span.startTime).toNanoseconds
                        message += "  \(event.name) Time: +\(ts) Attributes: \(event.attributes)\n"
                    }
                }

                message += "--------------------\n"

                return message
            }
        }

        return proxyExporter.export(spans: spans)
    }

    func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        proxyExporter.flush(explicitTimeout: explicitTimeout)
    }

    func shutdown(explicitTimeout: TimeInterval?) {
        proxyExporter.shutdown(explicitTimeout: explicitTimeout)
    }
}
