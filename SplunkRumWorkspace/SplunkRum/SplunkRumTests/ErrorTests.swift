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

// FIXME rewrite to use localSpans rather than receivedSpans
class ErrorTests: XCTestCase {
    enum EnumError: Error {
        case ExampleError
    }
    class ClassError: Error {

    }

    func testBasics() throws {
        let crashPath = Bundle(for: ErrorTests.self).url(forResource: "sample", withExtension: "plcrash")!
        let crashData = try Data(contentsOf: crashPath)
        try initializeTestEnvironment()
        SplunkRum.reportError(string: "Test message")
        SplunkRum.reportError(error: EnumError.ExampleError)
        SplunkRum.reportError(error: ClassError())
        SplunkRum.reportError(exception: NSException(name: NSExceptionName(rawValue: "IllegalFormatError"), reason: "Could not parse input", userInfo: nil))
        try loadPendingCrashReport(crashData) // creates span for the saved crash report

        print(localSpans as Any)
        let eStr = localSpans.first(where: { (span) -> Bool in
            return span.attributes["error.message"]?.description == "Test message"
        })
        let eEnumErr = localSpans.first(where: { (span) -> Bool in
            return (span.attributes["error.message"]?.description.contains("EnumError") ?? false)
        })
        let eClassErr = localSpans.first(where: { (span) -> Bool in
            return (span.attributes["error.message"]?.description.contains("ClassError") ?? false)
        })
        let eExc = localSpans.first(where: { (span) -> Bool in
            return span.attributes["error.message"]?.description == "Could not parse input"
        })
        let crashReport = localSpans.first(where: { (span) -> Bool in
            return span.name == "crash.report"
        })

        XCTAssertNotNil(eStr)
        XCTAssertEqual(eStr?.name, "SplunkRum.reportError")
        XCTAssertEqual(eStr?.attributes["error"]?.description, "true")
        XCTAssertEqual(eStr?.attributes["error.name"]?.description, "String")
        XCTAssertNotNil(eStr?.attributes["splunk.rumSessionId"])

        XCTAssertNotNil(eExc)
        XCTAssertEqual(eExc?.name, "SplunkRum.reportError")
        XCTAssertEqual(eExc?.attributes["error"]?.description, "true")
        XCTAssertEqual(eExc?.attributes["error.name"]?.description, "IllegalFormatError")
        XCTAssertNotNil(eExc?.attributes["splunk.rumSessionId"])

        XCTAssertNotNil(eEnumErr)
        XCTAssertEqual(eEnumErr?.name, "SplunkRum.reportError")
        XCTAssertEqual(eEnumErr?.attributes["error"]?.description, "true")
        XCTAssertNotNil(eEnumErr?.attributes["splunk.rumSessionId"])

        XCTAssertNotNil(eClassErr)
        XCTAssertEqual(eClassErr?.name, "SplunkRum.reportError")
        XCTAssertEqual(eClassErr?.attributes["error"]?.description, "true")
        XCTAssertNotNil(eClassErr?.attributes["splunk.rumSessionId"])

        XCTAssertEqual(eClassErr?.attributes["splunk.rumSessionId"], eExc?.attributes["splunk.rumSessionId"])

        XCTAssertNotNil(crashReport)
        XCTAssertNotEqual(crashReport?.attributes["splunk.rumSessionId"], crashReport?.attributes["crash.rumSessionId"])
        XCTAssertEqual(crashReport?.attributes["crash.rumSessionId"]?.description, "355ecc42c29cf0b56c411f1eab9191d0")
        XCTAssertEqual(crashReport?.attributes["crash.address"]?.description, "140733995048756")
        XCTAssertEqual(crashReport?.attributes["error"]?.description, "true")
        XCTAssertEqual(crashReport?.attributes["error.name"]?.description, "SIGILL")

        let beacon = receivedSpans.first(where: { (span) -> Bool in
            return span.tags["http.url"]?.contains("/v1/traces") ?? false
        })
        XCTAssertNil(beacon)
    }
}
