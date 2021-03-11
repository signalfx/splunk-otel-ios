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

import Foundation
import XCTest
@testable import SplunkRum
import StdoutExporter
import OpenTelemetrySdk

class UtilsTests: XCTestCase {

    func testSessionId() throws {
        let s1 = generateNewSessionId()
        let s2 = generateNewSessionId()
        XCTAssertNotEqual(s1, s2)
        XCTAssertEqual(s1.count, 32)
        for char in s1 {
            XCTAssertTrue(("0"..."9").contains(char) || ("a"..."f").contains(char))
        }
    }

    func testLimitingExporter() throws {
        try initializeTestEnvironment()
        // This test is shaped kinda funny since we can't construct SpanData() directly
        let span = buildTracer().spanBuilder(spanName: "limitTest").startSpan()
        var longString = "0123456789abcdef"
        var i = 0
        while i < 9 {
            longString += longString
            i += 1
        }
        XCTAssertTrue(longString.count > 4096)
        span.setAttribute(key: "longString", value: longString)
        span.setAttribute(key: "normalString", value: "normal")
        span.setAttribute(key: "normalInt", value: 7)
        span.end()
        XCTAssertEqual(1, localSpans.count)
        let rawSpans = localSpans
        XCTAssertTrue(rawSpans[0].attributes["longString"]?.description.count ?? 0 > 4096)
        localSpans.removeAll()
        let le = LimitingExporter(proxy: TestSpanExporter()) // rewrites into localSpans; yes, this is weird
        _ = le.export(spans: rawSpans)
        XCTAssertEqual(1, localSpans.count)
        XCTAssertTrue(localSpans[0].attributes["longString"]?.description.count ?? 4097 <= 4096)
        XCTAssertEqual("normal", localSpans[0].attributes["normalString"]?.description ?? nil)
        XCTAssertEqual("7", localSpans[0].attributes["normalInt"]?.description ?? nil)
    }

}
