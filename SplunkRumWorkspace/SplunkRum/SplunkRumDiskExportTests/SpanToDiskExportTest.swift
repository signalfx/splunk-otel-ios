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
import XCTest
@testable import SplunkOtel

class SpanToDiskExportTest: XCTestCase {

    func testExport() throws {
        let db = SpanDb(path: ":memory:")
        let exporter = SpanToDiskExporter(spanDb: db)
        let spans = [
            makeSpanData("s1"),
            makeSpanData("s2")
        ]
        XCTAssertEqual(exporter.export(spans: spans), SpanExporterResultCode.success)
        let exportedSpans = db.fetch(count: 10)

        XCTAssertEqual(exportedSpans.count, 2)
    }

    func testTruncationOnFirstExport() {
        let db = SpanDb(path: ":memory:")
        let exporter = SpanToDiskExporter(spanDb: db, maxFileSizeBytes: 128, truncationCheckpoint: 1_000)
        var initialSpans: [ZipkinSpan] = []

        for id in 1...100 {
            initialSpans.append(makeSpan(name: "s\(id)", timestamp: UInt64(id)))
        }

        XCTAssertTrue(db.store(spans: initialSpans))
        XCTAssertEqual(exporter.export(spans: [makeSpanData("s101")]), SpanExporterResultCode.success)
        XCTAssertEqual(db.fetch(count: 512).count, 81)
    }

    func testTruncationAfterCheckpoint() {
        let db = SpanDb(path: ":memory:")
        let exporter = SpanToDiskExporter(spanDb: db, maxFileSizeBytes: 128, truncationCheckpoint: 100)
        var spans: [SpanData] = []
        var id = 1

        for _ in 1...50 {
            spans.append(makeSpanData("s\(id)"))
            id += 1
        }

        XCTAssertEqual(exporter.export(spans: spans), SpanExporterResultCode.success)
        // First truncation will happen due to low max DB size
        XCTAssertEqual(db.fetch(count: 512).count, 40)

        spans = []
        for _ in 1...100 {
            spans.append(makeSpanData("s\(id)"))
            id += 1
        }
        XCTAssertEqual(exporter.export(spans: spans), SpanExporterResultCode.success)

        // Drop 20% of 140 spans
        XCTAssertEqual(db.fetch(count: 512).count, 112)
    }

    func testNoTruncationWithLargeMaxSize() {
        let db = SpanDb(path: ":memory:")
        let exporter = SpanToDiskExporter(spanDb: db, maxFileSizeBytes: INT64_MAX, truncationCheckpoint: 10)
        var spans: [SpanData] = []
        var id = 1

        for _ in 1...50 {
            spans.append(makeSpanData("s\(id)"))
            id += 1
        }

        XCTAssertEqual(exporter.export(spans: spans), SpanExporterResultCode.success)
        XCTAssertEqual(db.fetch(count: 512).count, 50)

        spans = []
        for _ in 1...100 {
            spans.append(makeSpanData("s\(id)"))
            id += 1
        }
        XCTAssertEqual(exporter.export(spans: spans), SpanExporterResultCode.success)
        XCTAssertEqual(db.fetch(count: 512).count, 150)
    }
}
