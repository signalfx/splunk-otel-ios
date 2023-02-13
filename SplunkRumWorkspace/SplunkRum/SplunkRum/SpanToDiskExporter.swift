//
/*
Copyright 2022 Splunk Inc.

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

class SpanToDiskExporter: SpanExporter {
    let db: SpanDb
    let maxFileSizeBytes: Int64
    // Count of spans to insert before checking whether truncation is necessary
    let truncationCheckpoint: Int64
    private var totalSpansInserted: Int64 = 0
    private var checkpointCounter: Int64 = 0

    init(spanDb: SpanDb, maxFileSizeBytes: Int64 = 25 * 1024 * 1024, truncationCheckpoint: Int64 = 512) {
        self.db = spanDb
        self.maxFileSizeBytes = maxFileSizeBytes
        self.truncationCheckpoint = truncationCheckpoint
    }

    public func flush() -> SpanExporterResultCode {
        return .success
    }

    public func shutdown() {}

    public func export(spans: [SpanData]) -> SpanExporterResultCode {
        if !db.ready() {
            return .failure
        }

        if !db.store(spans: ZipkinConversionExtension.toZipkinSpans(spans: spans)) {
            return .failure
        }

        let inserted = Int64(spans.count)
        checkpointCounter += inserted

        // There might be a case where truncation checkpoint is never reached,
        // so do a size check / truncation after the first insert.
        if totalSpansInserted == 0 || checkpointCounter >= truncationCheckpoint {
            maybeTruncate()
        }

        totalSpansInserted += inserted

        return .success
    }

    private func maybeTruncate() {
        guard let dbSize = db.getSize() else {
            return
        }

        if dbSize < self.maxFileSizeBytes {
            return
        }

        _ = db.truncate()

        checkpointCounter = 0
    }
}
