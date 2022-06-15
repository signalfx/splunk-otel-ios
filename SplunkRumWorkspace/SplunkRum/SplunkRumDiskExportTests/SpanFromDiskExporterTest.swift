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

import XCTest
@testable import SplunkRum

class SpanFromDiskExporterTest: XCTestCase {

    func testExportingRemovesSpan() throws {
        let receiver = TestSpanReceiver()
        try receiver.start(9722)
        let db = SpanDb(path: ":memory:")

        _ = db.store(spans: [
            makeSpan(name: "s1", timestamp: 1, tags: ["foo": "1"]),
            makeSpan(name: "s2", timestamp: 2, tags: ["bar": "2"])
        ])

        let stop = SpanFromDiskExport.start(spanDb: db, endpoint: "http://localhost:9722/v1/traces")

        defer {
            stop()
        }

        var secondsWaited = 0
        while receiver.receivedSpans.isEmpty {
            sleep(1)
            secondsWaited += 1

            if secondsWaited >= 10 {
                XCTFail("Timed out waiting for spans")
                return
            }
        }

        let spans = receiver.spans()
        XCTAssertEqual(spans.count, 2)
        XCTAssertEqual(db.fetch(count: 10).count, 0)
    }

    func testFailedExportingDoesNotRemoveSpans() throws {
        let receiver = TestSpanReceiver()
        try receiver.start(9721)

        let db = SpanDb(path: ":memory:")

        _ = db.store(spans: [
            makeSpan(name: "s1", timestamp: 1, tags: ["foo": "1"]),
            makeSpan(name: "s2", timestamp: 2, tags: ["bar": "2"])
        ])

        let stop = SpanFromDiskExport.start(spanDb: db, endpoint: "http://localhost:9721/oops")

        defer {
            stop()
        }

        var secondsWaited = 0
        while !receiver.receivedRequest {
            sleep(1)
            secondsWaited += 1

            if secondsWaited >= 10 {
                XCTFail("Timed out waiting for spans")
                return
            }
        }

        let spans = receiver.spans()
        XCTAssertEqual(spans.count, 0)
        XCTAssertEqual(db.fetch(count: 10).count, 2)
    }
}
