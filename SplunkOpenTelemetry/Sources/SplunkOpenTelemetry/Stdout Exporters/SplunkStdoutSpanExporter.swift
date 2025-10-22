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
import OpenTelemetrySdk
import SplunkCommon

/// Prints Span contents into the console using an internal logger.
class SplunkStdoutSpanExporter: SpanExporter {

    // MARK: - Private

    /// The proxy exporter.
    private let proxyExporter: SpanExporter

    /// Logger for the module.
    private let logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "OpenTelemetry")


    // MARK: - Initialization

    init(proxyExporter: SpanExporter) {
        self.proxyExporter = proxyExporter
    }


    // MARK: - SpanExporter

    func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        for span in spans {
            log(span: span)
        }

        return proxyExporter.export(spans: spans, explicitTimeout: explicitTimeout)
    }

    func shutdown(explicitTimeout: TimeInterval?) {
        proxyExporter.shutdown(explicitTimeout: explicitTimeout)
    }

    // MARK: - Private methods

    private func log(span: SpanData) {
        logger.log(level: .debug) {
            var message = ""

            message += "------ 🔭 Span: ------\n"
            message += "TraceId: \(span.traceId.hexString)\n"
            message += "SpanId: \(span.spanId.hexString)\n"
            message += "ParentSpanId: \(span.parentSpanId?.hexString ?? "nil")\n"
            message += "Name: \(span.name)\n"
            message += "Kind: \(span.kind)\n"
            message += "Status: \(span.status)\n"
            message += "StartTime: \(span.startTime.timeIntervalSince1970.toNanoseconds) (\(span.startTime.splunkFormatted()))\n"
            message += "EndTime: \(span.endTime.timeIntervalSince1970.toNanoseconds) (\(span.endTime.splunkFormatted()))\n"
            message += "HasRemoteParent: \(span.hasRemoteParent)\n"
            message += "TotalRecordedEvents: \(span.totalRecordedEvents)\n"
            message += "TotalRecordedLinks: \(span.totalRecordedLinks)\n"
            message += "TotalAttributes: \(span.totalAttributeCount)\n"

            // Log attributes
            message += "Attributes:\n"
            message += "  \(span.attributes)\n"

            // Log events
            message += "Events:\n"
            for event in span.events {
                message += "  \(event)\n"
            }

            // Log links
            message += "Links:\n"
            for link in span.links {
                message += "  \(link)\n"
            }

            // Log resources
            message += "Resource:\n"
            message += "  \(span.resource.attributes)\n"

            message += "--------------------\n"

            return message
        }
    }
}
