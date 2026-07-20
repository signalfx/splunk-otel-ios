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

/// Test exporter whose first `export` call blocks (holding the processor's serial queue) until released.
///
/// Subsequent calls return immediately. Counts every span it receives.
final class FirstExportBlockingExporter: SpanExporter {
    private let lock = NSLock()
    private let started = DispatchSemaphore(value: 0)
    private let release = DispatchSemaphore(value: 0)

    private var receivedCount = 0
    private var isFirstExport = true

    var receivedSpanCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return receivedCount
    }

    func export(spans: [SpanData], explicitTimeout _: TimeInterval?) -> SpanExporterResultCode {
        lock.lock()
        receivedCount += spans.count
        let shouldBlock = isFirstExport
        isFirstExport = false
        lock.unlock()

        if shouldBlock {
            started.signal()
            release.wait()
        }

        return .success
    }

    func flush(explicitTimeout _: TimeInterval?) -> SpanExporterResultCode {
        .success
    }

    func shutdown(explicitTimeout _: TimeInterval?) {}

    func waitUntilFirstExportStarts(timeout: TimeInterval) -> DispatchTimeoutResult {
        started.wait(timeout: .now() + timeout)
    }

    func releaseFirstExport() {
        release.signal()
    }
}
