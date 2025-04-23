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

class AttributeCheckerSpanExporter: SpanExporter {

    // MARK: - Private

    private let requiredAttributes = [
        "component",
        "screen.name",
        "session.id"
    ]

    private let proxyExporter: SpanExporter

    // Internal Logger
    private let logger = DefaultLogAgent(poolName: "com.splunk.rum", category: "OpenTelemetry")


    // MARK: - Initialization

    init(proxy: SpanExporter) {
        proxyExporter = proxy
    }


    // MARK: - SpanExporter

    func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        check(spans: spans)

        return proxyExporter.export(spans: spans, explicitTimeout: explicitTimeout)
    }

    func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        proxyExporter.flush(explicitTimeout: explicitTimeout)
    }

    func shutdown(explicitTimeout: TimeInterval?) {
        proxyExporter.shutdown(explicitTimeout: explicitTimeout)
    }


    // MARK: - Check

    private func check(spans: [SpanData]) {
        for span in spans {
            for requiredAttribute in requiredAttributes {
                guard let _ = span.attributes[requiredAttribute] else {
                    let spanName = span.name

                    logger.log(level: .error) {
                        """
                        ‼️‼️‼️ Span \(spanName) is missing a required attribute: \"\(requiredAttribute)\"
                        Attributes: \(span.attributes)
                        """
                    }

                    continue
                }
            }
        }
    }
}
