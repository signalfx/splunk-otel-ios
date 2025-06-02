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

public typealias SplunkSpanInterceptor = (SpanData) -> SpanData?

class SpanInterceptorExporter: SpanExporter {

    // MARK: - Private

    private let spanInterceptor: SplunkSpanInterceptor?

    private let proxyExporter: SpanExporter


    // MARK: - Initialization

    init(with interceptor: SplunkSpanInterceptor?, proxy: SpanExporter) {
        spanInterceptor = interceptor
        proxyExporter = proxy
    }


    // MARK: - Span Exporter methods

    func shutdown(explicitTimeout: TimeInterval?) {
        proxyExporter.shutdown(explicitTimeout: explicitTimeout)
    }

    func flush(explicitTimeout: TimeInterval?) -> OpenTelemetrySdk.SpanExporterResultCode {
        proxyExporter.flush(explicitTimeout: explicitTimeout)
    }

    func export(spans: [OpenTelemetrySdk.SpanData], explicitTimeout: TimeInterval?) -> OpenTelemetrySdk.SpanExporterResultCode {

        // Simply re-export the spans if no interceptor was set.
        guard let spanInterceptor else {
            return proxyExporter.export(spans: spans)
        }

        // Invoke the interceptor and only pass through non-nil spans.
        let interceptedSpans = spans.compactMap({ span in return spanInterceptor(span)})

        return proxyExporter.export(spans: interceptedSpans)
    }
}
