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

final class BatchProcessorTestExporter: SpanExporter {
    private let lock = NSLock()
    private let exportCompleted = DispatchSemaphore(value: 0)
    private let exportStarted = DispatchSemaphore(value: 0)
    private let exportResume = DispatchSemaphore(value: 0)
    private let blockExports: Bool

    private var results: [SpanExporterResultCode]
    private var storedBatches: [[SpanData]] = []
    private var storedSuccessfulSpans: [SpanData] = []
    private var storedExportTimeouts: [TimeInterval?] = []
    private var storedExportAttemptCount = 0
    private var storedFlushCount = 0
    private var storedShutdownCount = 0

    init(
        results: [SpanExporterResultCode] = [],
        blockExports: Bool = false
    ) {
        self.results = results
        self.blockExports = blockExports
    }

    var batches: [[SpanData]] {
        withLock { storedBatches }
    }

    var successfulSpanNames: [String] {
        withLock { storedSuccessfulSpans.map(\.name) }
    }

    var successfulSpanCount: Int {
        withLock { storedSuccessfulSpans.count }
    }

    var exportAttemptCount: Int {
        withLock { storedExportAttemptCount }
    }

    var exportTimeouts: [TimeInterval?] {
        withLock { storedExportTimeouts }
    }

    var flushCount: Int {
        withLock { storedFlushCount }
    }

    var shutdownCount: Int {
        withLock { storedShutdownCount }
    }

    func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        exportStarted.signal()
        if blockExports {
            exportResume.wait()
        }

        let result = withLock {
            storedExportAttemptCount += 1
            storedBatches.append(spans)
            storedExportTimeouts.append(explicitTimeout)

            let result = results.isEmpty ? SpanExporterResultCode.success : results.removeFirst()
            if result == .success {
                storedSuccessfulSpans.append(contentsOf: spans)
            }
            return result
        }

        exportCompleted.signal()
        return result
    }

    func flush(explicitTimeout _: TimeInterval?) -> SpanExporterResultCode {
        withLock {
            storedFlushCount += 1
        }
        return .success
    }

    func shutdown(explicitTimeout _: TimeInterval?) {
        withLock {
            storedShutdownCount += 1
        }
    }

    func waitForExport(timeout: TimeInterval) -> DispatchTimeoutResult {
        exportCompleted.wait(timeout: .now() + timeout)
    }

    func waitUntilExportStarts(timeout: TimeInterval) -> DispatchTimeoutResult {
        exportStarted.wait(timeout: .now() + timeout)
    }

    func resumeExports() {
        exportResume.signal()
    }

    private func withLock<T>(_ work: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try work()
    }
}
