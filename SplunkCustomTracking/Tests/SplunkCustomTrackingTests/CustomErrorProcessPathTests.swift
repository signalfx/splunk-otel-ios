//
/*
Copyright 2026 Splunk Inc.

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

@testable import SplunkCommon
@testable import SplunkCustomTracking

final class CustomErrorProcessPathTests: XCTestCase {
    private var module: CustomTrackingInternal?
    private var capturedData: CustomTrackingData?
    private var expectation: XCTestExpectation?

    override func setUp() {
        super.setUp()

        module = CustomTrackingInternal()
        expectation = XCTestExpectation(description: "onPublishBlock for error was called")

        module?.onPublishBlock = { [weak self] _, data in
            self?.capturedData = data
            self?.expectation?.fulfill()
        }
    }

    override func tearDown() {
        module = nil
        capturedData = nil
        expectation = nil

        super.tearDown()
    }

    func testTrackError_withString_omitsCrashProcessPath() throws {
        let module = try XCTUnwrap(module)
        let expectation = try XCTUnwrap(expectation)

        module.track(SplunkIssue(from: "message"), [:])

        wait(for: [expectation], timeout: 1.0)

        let data = try XCTUnwrap(capturedData)
        XCTAssertNil(data.attributes["crash.processPath"])
    }

    func testTrackError_withSwiftError_attachesCrashProcessPathWhenBinaryImagesDisabled() throws {
        struct FileError: Error, LocalizedError {
            var errorDescription: String? {
                "File not found"
            }
        }

        let module = try XCTUnwrap(module)
        let expectation = try XCTUnwrap(expectation)
        module.install(
            with: CustomTrackingConfiguration(includeBinaryImagesOnErrors: false),
            remoteConfiguration: nil
        )

        module.track(SplunkIssue(from: FileError()), [:])

        wait(for: [expectation], timeout: 1.0)

        let data = try XCTUnwrap(capturedData)
        XCTAssertNotNil(getStringValue(for: "crash.processPath", in: data))
        XCTAssertNil(data.attributes["exception.images"])
    }

    func testTrackException_attachesCrashProcessPath() throws {
        let module = try XCTUnwrap(module)
        let expectation = try XCTUnwrap(expectation)
        module.install(
            with: CustomTrackingConfiguration(includeBinaryImagesOnErrors: true),
            remoteConfiguration: nil
        )

        let exception = NSException(name: NSExceptionName("TestException"), reason: "reason", userInfo: nil)
        module.track(SplunkIssue(from: exception), [:])

        wait(for: [expectation], timeout: 1.0)

        let data = try XCTUnwrap(capturedData)
        XCTAssertNotNil(getStringValue(for: "crash.processPath", in: data))
    }
}
