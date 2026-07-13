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

/// A span processor that exports ended spans synchronously on the caller path.
///
/// This is intentionally used only for log-to-span telemetry where completion historically meant
/// the converted span had reached the disk-backed exporter. Direct span instrumentation uses
/// ``OTLPBatchSpanProcessor`` to reduce disk churn.
struct OTLPImmediateSpanProcessor: SpanProcessor {

    // MARK: - Private properties

    private let spanExporter: SpanExporter


    // MARK: - SpanProcessor settings

    let isStartRequired = false

    let isEndRequired = true


    // MARK: - Initialization

    init(spanExporter: SpanExporter) {
        self.spanExporter = spanExporter
    }


    // MARK: - SpanProcessor methods

    func onStart(parentContext _: SpanContext?, span _: ReadableSpan) {}

    func onEnd(span: ReadableSpan) {
        guard span.context.traceFlags.sampled else {
            return
        }

        _ = spanExporter.export(spans: [span.toSpanData()], explicitTimeout: nil)
    }

    func shutdown(explicitTimeout: TimeInterval?) {
        spanExporter.shutdown(explicitTimeout: explicitTimeout)
    }

    func forceFlush(timeout: TimeInterval?) {
        _ = spanExporter.flush(explicitTimeout: timeout)
    }
}
