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
import OpenTelemetrySdk

@testable import SplunkOpenTelemetry

/// Stands in for the background exporter, which is the stage after the session policy.
///
/// Safety: spans arrive on the export thread while the test reads them, and `lock` guards `recordedSpans`.
/// A `Mutex` (iOS 18 and later) would remove the `@unchecked`.
final class RecordingTraceExporter: EndpointConfigurableSpanExporter, @unchecked Sendable {

    // MARK: - Private

    private let lock = NSLock()
    private var recordedSpans: [SpanData] = []


    // MARK: - Public

    var spans: [SpanData] {
        lock.lock()
        defer { lock.unlock() }

        return recordedSpans
    }


    // MARK: - SpanExporter methods

    func export(spans: [SpanData], explicitTimeout _: TimeInterval?) -> SpanExporterResultCode {
        lock.lock()
        recordedSpans.append(contentsOf: spans)
        lock.unlock()

        return .success
    }

    func flush(explicitTimeout _: TimeInterval?) -> SpanExporterResultCode {
        .success
    }

    func shutdown(explicitTimeout _: TimeInterval?) {}


    // MARK: - EndpointConfigurableSpanExporter methods

    func setEndpoint(_: URL, headers _: [String: String]?) {}

    func clearEndpoint() {}
}
