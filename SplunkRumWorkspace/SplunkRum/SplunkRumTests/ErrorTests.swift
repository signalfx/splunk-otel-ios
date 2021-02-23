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
    enum EnumError : Error {
        case ExampleError
    }
    class ClassError : Error {
        
    }
    func testBasics() throws {
        try initializeTestEnvironment()
        SplunkRum.reportError(string: "Test message")
        SplunkRum.reportError(error: EnumError.ExampleError)
//        SplunkRum.reportError(error: ClassError())
        SplunkRum.reportError(exception: NSException(name: NSExceptionName(rawValue: "IllegalFormatError"), reason: "Could not parse input", userInfo: nil))
        
        print("sleeping to wait for span batch, don't worry about the pause...")
        sleep(8)
        print(receivedSpans as Any)
        let eStr = receivedSpans.first(where: { (span) -> Bool in
            return span.tags["error.message"] == "Test message"
        })
        let eErr = receivedSpans.first(where: { (span) -> Bool in
            return (span.tags["error.message"]?.contains("EnumError") ?? false)
        })
        let eExc = receivedSpans.first(where: { (span) -> Bool in
            return span.tags["error.message"] == "Could not parse input"
        })
        
        XCTAssertNotNil(eStr)
        XCTAssertEqual(eStr?.tags["error"], "true")
        XCTAssertEqual(eStr?.tags["error.name"], "String")

        XCTAssertNotNil(eExc)
        XCTAssertEqual(eExc?.tags["error"], "true")
        XCTAssertEqual(eExc?.tags["error.name"], "IllegalFormatError")

        XCTAssertNotNil(eErr)
        XCTAssertEqual(eErr?.tags["error"], "true")

    }
}

