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

@testable import SplunkAgent
import SplunkCustomTracking
import XCTest

final class CustomTrackingAPI10ModuleProxyTests: XCTestCase {


    // MARK: - Private

    private var module: SplunkCustomTracking.CustomTracking!
    private var moduleProxy: SplunkAgent.CustomTracking!


    // MARK: - Tests lifecycle

    override func setUp() {
        super.setUp()

        module = SplunkCustomTracking.CustomTracking()
        moduleProxy = SplunkAgent.CustomTracking(for: module)
    }


    // MARK: - Custom Tracking: Event

    func testTrackCustomEvent() throws {
        let attributes = MutableAttributes()
        XCTAssertNoThrow(moduleProxy.trackCustomEvent("testEvent", attributes))
    }


    // MARK: - Custom Tracking: Errors

    func testTrackError_withString() throws {
        let attributes = MutableAttributes()
        XCTAssertNoThrow(moduleProxy.trackError("Test error message", attributes))
    }
    func testTrackError_withError() throws {
        let attributes = MutableAttributes()
        let error = NSError(domain: "com.splunk.test", code: 1, userInfo: nil) as Error
        XCTAssertNoThrow(moduleProxy.trackError(error, attributes))
    }
    func testTrackError_withNSError() throws {
        let attributes = MutableAttributes()
        let nsError = NSError(domain: "com.splunk.test", code: 1, userInfo: nil)
        XCTAssertNoThrow(moduleProxy.trackError(nsError, attributes))
    }
    func testTrackError_withNSException() throws {
        let attributes = MutableAttributes()
        let exception = NSException(name: .genericException, reason: "Test exception", userInfo: nil)
        XCTAssertNoThrow(moduleProxy.trackException(exception, attributes))
    }
}
