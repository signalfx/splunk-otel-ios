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
import SplunkCommon

/// Prints Span contents into the console using an internal logger.
class SplunkStdoutSpanExporter: SpanExporter {

    // MARK: - Private

    private let proxyExporter: SpanExporter

    // Internal Logger
    private let logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "OpenTelemetry")

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

    init(with proxy: SpanExporter) {
        proxyExporter = proxy
    }

    func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
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
                message += "Start: \(span.startTime.timeIntervalSince1970.toNanoseconds) (\(span.startTime.formatted(self.dateFormatStyle)))\n"
                message += "End: \(span.endTime.timeIntervalSince1970.toNanoseconds) (\(span.endTime.formatted(self.dateFormatStyle)))\n"

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
    
    public func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        return proxyExporter.flush(explicitTimeout: explicitTimeout)
    }
    
    public func shutdown(explicitTimeout: TimeInterval?) {
        proxyExporter.shutdown(explicitTimeout: explicitTimeout)
    }
}
