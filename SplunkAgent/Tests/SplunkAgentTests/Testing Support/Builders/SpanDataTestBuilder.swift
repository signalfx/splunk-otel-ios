//
/*
Copyright 2026 Splunk Inc.

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
import OpenTelemetryApi
import OpenTelemetrySdk

/// Builds ended spans as `SpanData`, as an exporter receives them.
enum SpanDataTestBuilder {

    /// Starts and ends a span with the given name, start time and attributes.
    ///
    /// The span lasts 100 ms.
    static func build(
        name: String = "test",
        startTime: Date = Date(),
        attributes: [String: AttributeValue] = [:]
    ) -> SpanData {
        let provider = TracerProviderBuilder().build()
        let tracer = provider.get(instrumentationName: "span-data-test-builder")
        let span = tracer.spanBuilder(spanName: name)
            .setStartTime(time: startTime)
            .startSpan()

        for (key, value) in attributes {
            span.setAttribute(key: key, value: value)
        }
        span.end(time: startTime.addingTimeInterval(0.1))

        // The SDK tracer provider always creates readable spans.
        guard let readableSpan = span as? ReadableSpan else {
            preconditionFailure("Expected an SDK readable span")
        }

        return readableSpan.toSpanData()
    }
}
