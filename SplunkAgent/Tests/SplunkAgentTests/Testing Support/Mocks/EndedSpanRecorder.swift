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

/// A span processor that records each span when it ends.
///
/// Spans end on the thread that calls `end()`, which is the test's thread in the tests that use it.
final class EndedSpanRecorder: SpanProcessor {

    private(set) var spans: [SpanData] = []

    let isStartRequired = false
    let isEndRequired = true

    func onStart(parentContext _: SpanContext?, span _: ReadableSpan) {}

    func onEnd(span: ReadableSpan) {
        spans.append(span.toSpanData())
    }

    func shutdown(explicitTimeout _: TimeInterval?) {}

    func forceFlush(timeout _: TimeInterval?) {}
}
