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

class SpanTests: XCTestCase {
    func testEventSpan() throws {
        try initializeTestEnvironment()
        let dictionary: NSDictionary = [
                        "attribute1": "hello",
                        "attribute2": "world!",
                        "attribute3": 3
        ]
        SplunkRum.reportEvent(name: "testEvent", attributes: dictionary)
        XCTAssertEqual(localSpans.count, 1)
        
        let testSpan = localSpans.first(where: { (span) -> Bool in
            return span.name == "testEvent"
        })

        
        XCTAssertNotNil(testSpan)
        XCTAssertEqual(testSpan?.name, "testEvent")
        XCTAssertEqual(testSpan?.attributes["attribute1"]?.description, "hello")
        XCTAssertEqual(testSpan?.attributes["attribute2"]?.description, "world!")
        XCTAssertEqual(testSpan?.attributes["attribute3"]?.description, "3")
        XCTAssertEqual(testSpan?.startTime, testSpan?.endTime)
    }
}
