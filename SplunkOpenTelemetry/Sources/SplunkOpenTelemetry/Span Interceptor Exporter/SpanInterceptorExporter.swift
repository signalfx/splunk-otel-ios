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

/// A closure type that allows for inspecting or modifying `SpanData` before it is exported.
///
/// The interceptor receives the `SpanData` for a single span. It can return a modified
/// version of the `SpanData`, or it can return `nil` to prevent the span from being exported.
/// This is useful for filtering, redacting, or enriching span data at the last moment.
///
/// - Parameter span: The `SpanData` to be processed.
/// - Returns: A modified `SpanData` instance to be exported, or `nil` to drop the span.
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

        // Simply re-export the spans if no interceptor was set
        guard let spanInterceptor else {
            return proxyExporter.export(spans: spans)
        }

        // Invoke the interceptor and only pass through non-nil spans
        let interceptedSpans = spans.compactMap { span in
            spanInterceptor(span)
        }

        /*
         Recalculate `totalAttributeCount`.

         We allow attribute mutation in the `spanInterceptor`. SpanData stores information
         about total number of attributes (`totalAttributeCount`), which is used to calculate and track
         a number of dropped attributes in case of exceeding maximum number of attributes.
         Having `span.attributes.count` larger than `span.totalAttributeCount` causes a crash when calculating
         `droppedAttributesCount`.

         ‼️ By recalculating the `totalAttributeCount`, we effectively disable the `droppedAttributesCount` calculation,
         which means that the `droppedAttributesCount` will have a wrong value. If the `droppedAttributesCount` parameter
         is required in the future, we should consider another approach.
        */
        let recalculatedSpans = interceptedSpans.map {
            var span = $0
            let attributeCount = span.attributes.count

            if span.totalAttributeCount != attributeCount {
                return span.settingTotalAttributeCount(attributeCount)
            }

            return span
        }

        return proxyExporter.export(spans: recalculatedSpans)
    }
}
