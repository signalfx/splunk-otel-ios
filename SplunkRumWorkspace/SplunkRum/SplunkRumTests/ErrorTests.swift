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

        XCTAssertEqual(localSpans.count, 4)
        let eStr = localSpans.first(where: { (span) -> Bool in
            return span.attributes["exception.message"]?.description == "Test message"
        })
        let eEnumErr = localSpans.first(where: { (span) -> Bool in
            return (span.attributes["exception.message"]?.description.contains("EnumError") ?? false)
        })
        let eClassErr = localSpans.first(where: { (span) -> Bool in
            return (span.attributes["exception.message"]?.description.contains("ClassError") ?? false)
        })
        let eExc = localSpans.first(where: { (span) -> Bool in
            return span.attributes["exception.message"]?.description == "Could not parse input"
        })

        XCTAssertNotNil(eStr)
        XCTAssertEqual(eStr?.name, "SplunkRum.reportError(String)")
        XCTAssertEqual(eStr?.attributes["error"]?.description, "true")
        XCTAssertEqual(eStr?.attributes["exception.type"]?.description, "String")
        XCTAssertNotNil(eStr?.attributes["splunk.rumSessionId"])
        XCTAssertEqual(eStr?.attributes["component"]?.description, "error")

        XCTAssertNotNil(eExc)
        XCTAssertEqual(eExc?.name, "IllegalFormatError")
        XCTAssertEqual(eExc?.attributes["error"]?.description, "true")
        XCTAssertEqual(eExc?.attributes["exception.type"]?.description, "IllegalFormatError")
        XCTAssertNotNil(eExc?.attributes["splunk.rumSessionId"])
        XCTAssertEqual(eExc?.attributes["component"]?.description, "error")

        XCTAssertNotNil(eEnumErr)
        XCTAssertEqual(eEnumErr?.name, "EnumError")
        XCTAssertEqual(eEnumErr?.attributes["error"]?.description, "true")
        XCTAssertEqual(eEnumErr?.attributes["exception.type"]?.description, "EnumError")
        XCTAssertNotNil(eEnumErr?.attributes["splunk.rumSessionId"])
        XCTAssertEqual(eEnumErr?.attributes["component"]?.description, "error")

        XCTAssertNotNil(eClassErr)
        XCTAssertEqual(eClassErr?.name, "ClassError")
        XCTAssertEqual(eClassErr?.attributes["error"]?.description, "true")
        XCTAssertEqual(eClassErr?.attributes["component"]?.description, "error")
        XCTAssertNotNil(eClassErr?.attributes["splunk.rumSessionId"])
        XCTAssertEqual(eClassErr?.attributes["exception.type"]?.description, "ClassError")

        XCTAssertEqual(eClassErr?.attributes["splunk.rumSessionId"], eExc?.attributes["splunk.rumSessionId"])

    }
}
