//
/*
Copyright 2025 Splunk Inc.

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

@testable import SplunkAgent
@testable import SplunkCommon

final class CustomTrackingAPI10NoOpProxyTests: XCTestCase {

    // MARK: - Private

    private let moduleProxy = CustomTrackingTestBuilder.buildNonOperational()


    // MARK: - Custom Tracking: Event

    func testTrackCustomEvent() throws {
        let attributes = MutableAttributes()
        XCTAssertNotNil(moduleProxy.trackCustomEvent("testEvent", attributes))
    }


    // MARK: - Custom Tracking: Errors

    func testTrackErrorString() throws {
        let testErrorString = "TestErrorString"
        XCTAssertNotNil(moduleProxy.trackError(testErrorString))
    }

    func testTrackError() throws {
        struct TestError: Error {}
        let testError = TestError()
        XCTAssertNotNil(moduleProxy.trackError(testError))
    }

    func testTrackNSError() throws {
        let testNSError = NSError(domain: "TestDomain", code: 0, userInfo: nil)
        XCTAssertNotNil(moduleProxy.trackError(testNSError))
    }

    func testTrackException() throws {
        let exceptionName = NSExceptionName("TestException")
        let testException = NSException(name: exceptionName, reason: nil, userInfo: nil)
        XCTAssertNotNil(moduleProxy.trackException(testException))
    }

    func testTrackWorkflow() throws {
        let testWorkflowString = "TestWorkflow"
        XCTAssertNotNil(moduleProxy.trackWorkflow(testWorkflowString))
    }
}
