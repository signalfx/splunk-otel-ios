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
import SplunkRum

class ErrorTests: XCTestCase {
    enum EnumError: Error {
        case ExampleError
    }
    class ClassError: Error {

    }
    func testBasics() throws {
        try initializeTestEnvironment()
        SplunkRum.reportError(string: "Test message")
        SplunkRum.reportError(error: EnumError.ExampleError)
        SplunkRum.reportError(error: ClassError())
        SplunkRum.reportError(exception: NSException(name: NSExceptionName(rawValue: "IllegalFormatError"), reason: "Could not parse input", userInfo: nil))

        print("sleeping to wait for span batch, don't worry about the pause...")
        sleep(8)
        print(receivedSpans as Any)
        let eStr = receivedSpans.first(where: { (span) -> Bool in
            return span.tags["error.message"] == "Test message"
        })
        let eEnumErr = receivedSpans.first(where: { (span) -> Bool in
            return (span.tags["error.message"]?.contains("EnumError") ?? false)
        })
        let eClassErr = receivedSpans.first(where: { (span) -> Bool in
            return (span.tags["error.message"]?.contains("ClassError") ?? false)
        })
        let eExc = receivedSpans.first(where: { (span) -> Bool in
            return span.tags["error.message"] == "Could not parse input"
        })

        XCTAssertNotNil(eStr)
        XCTAssertEqual(eStr?.name, "SplunkRum.reportError")
        XCTAssertEqual(eStr?.tags["error"], "true")
        XCTAssertEqual(eStr?.tags["error.name"], "String")
        XCTAssertNotNil(eStr?.tags["splunk.rumSessionId"])

        XCTAssertNotNil(eExc)
        XCTAssertEqual(eExc?.name, "SplunkRum.reportError")
        XCTAssertEqual(eExc?.tags["error"], "true")
        XCTAssertEqual(eExc?.tags["error.name"], "IllegalFormatError")
        XCTAssertNotNil(eExc?.tags["splunk.rumSessionId"])

        XCTAssertNotNil(eEnumErr)
        XCTAssertEqual(eEnumErr?.name, "SplunkRum.reportError")
        XCTAssertEqual(eEnumErr?.tags["error"], "true")
        XCTAssertNotNil(eEnumErr?.tags["splunk.rumSessionId"])

        XCTAssertNotNil(eClassErr)
        XCTAssertEqual(eClassErr?.name, "SplunkRum.reportError")
        XCTAssertEqual(eClassErr?.tags["error"], "true")
        XCTAssertNotNil(eClassErr?.tags["splunk.rumSessionId"])

        XCTAssertEqual(eClassErr?.tags["splunk.rumSessionId"], eExc?.tags["splunk.rumSessionId"])

        let beacon = receivedSpans.first(where: { (span) -> Bool in
            return span.tags["http.url"]?.contains("/v1/traces") ?? false
        })
        XCTAssertNil(beacon)

    }
}
