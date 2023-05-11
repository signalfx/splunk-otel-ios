//
/*
Copyright 2021 Splunk Inc.

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
@testable import SplunkOtel

fileprivate let receiver = TestSpanReceiver()
fileprivate var started = false

class DiskExportPipelineTest: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        if started {
            receiver.reset()
            return
        }
        try receiver.start(9733)

        SpanDb.deleteAtDefaultLocation()

        XCTAssertTrue(
            SplunkRumBuilder(beaconUrl: "http://localhost:9733/v1/traces", rumAuth: "FAKE")
                .allowInsecureBeacon(enabled: true)
                .debugEnabled(enabled: true)
                .enableDiskCache(enabled: true)
                .spanDiskCacheMaxSize(size: 4096 * 4)
                .build()
        )

        started = true
    }

    func testExportPipeline() throws {
        for _ in 1...32 {
            let span = buildTracer().spanBuilder(spanName: "large-span").startSpan()
            span.setAttribute(key: "large-attribute", value: String(repeating: "abcd", count: 256))
            span.setAttribute(key: "large-attribute-2", value: String(repeating: "abcd", count: 256))
            span.end()
        }

        let spans = try receiver.waitForSpans().filter { $0.name == "large-span" }
        // Assert all spans were either exported or dropped from disk.
        XCTAssertEqual(SpanDb().fetch(count: 32).count, 0)
        // The exported size is less than we sent, this means remaining spans were dropped.
        XCTAssertLessThan(spans.count, 32)
        // And make sure we didn't receive an empty array
        XCTAssertGreaterThan(spans.count, 0)
    }
}
