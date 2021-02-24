//
//  ErrorTests.swift
//  SplunkRumTests
//
//  Created by jbley on 2/23/21.
//

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

        XCTAssertNotNil(eExc)
        XCTAssertEqual(eExc?.name, "SplunkRum.reportError")
        XCTAssertEqual(eExc?.tags["error"], "true")
        XCTAssertEqual(eExc?.tags["error.name"], "IllegalFormatError")

        XCTAssertNotNil(eEnumErr)
        XCTAssertEqual(eEnumErr?.name, "SplunkRum.reportError")
        XCTAssertEqual(eEnumErr?.tags["error"], "true")

        XCTAssertNotNil(eClassErr)
        XCTAssertEqual(eClassErr?.name, "SplunkRum.reportError")
        XCTAssertEqual(eClassErr?.tags["error"], "true")

    }
}
