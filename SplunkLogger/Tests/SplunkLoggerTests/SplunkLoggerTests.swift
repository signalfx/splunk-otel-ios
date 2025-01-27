//
/*
Copyright 2024 Splunk Inc.

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

@testable import SplunkLogger
import XCTest

struct NoopLogger: LoggerProvider, LoggerVerbosityValidator {
    var configuration: InternalLoggerConfiguration

    func log(level: LogLevel, isPrivate: Bool, message: String) {}
}

final class SplunkLoggerTests: XCTestCase {
    var logger: (LoggerProvider & LoggerVerbosityValidator)!
    var configuration: InternalLoggerConfiguration!

    override func tearDown() {
        super.tearDown()

        logger = nil
        configuration = nil
    }

    func testShouldLogLevels_givenSilentVerbosity() throws {
        configuration = InternalLoggerConfiguration(verbosity: .silent, subsystem: "com.splunk.rum.tests")
        logger = NoopLogger(configuration: configuration)

        let shouldLogError = logger.shouldLog(at: .error)
        let shouldLogNotice = logger.shouldLog(at: .notice)
        let shouldLogDebug = logger.shouldLog(at: .debug)

        XCTAssertFalse(shouldLogError)
        XCTAssertFalse(shouldLogNotice)
        XCTAssertFalse(shouldLogDebug)
    }

    func testShouldLogLevels_givenStandardVerbosity() throws {
        configuration = InternalLoggerConfiguration(verbosity: .standard, subsystem: "com.splunk.rum.tests")
        logger = NoopLogger(configuration: configuration)

        let shouldLogError = logger.shouldLog(at: .error)
        let shouldLogNotice = logger.shouldLog(at: .notice)
        let shouldLogDebug = logger.shouldLog(at: .debug)

        XCTAssertTrue(shouldLogError)
        XCTAssertTrue(shouldLogNotice)
        XCTAssertFalse(shouldLogDebug)
    }

    func testShouldLogLevels_givenVerboseVerbosity() throws {
        configuration = InternalLoggerConfiguration(verbosity: .verbose, subsystem: "com.splunk.rum.tests")
        logger = NoopLogger(configuration: configuration)

        let shouldLogError = logger.shouldLog(at: .error)
        let shouldLogNotice = logger.shouldLog(at: .notice)
        let shouldLogDebug = logger.shouldLog(at: .debug)

        XCTAssertTrue(shouldLogError)
        XCTAssertTrue(shouldLogNotice)
        XCTAssertTrue(shouldLogDebug)
    }
}
