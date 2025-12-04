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

import SplunkAppStart
import XCTest

@testable import SplunkAgent

final class AppStartAPI10ModuleProxyTests: XCTestCase {

    // MARK: - Private

    private var module: SplunkAppStart.AppStart?
    private var moduleProxy: SplunkAgent.AppStart?


    // MARK: - Setup and teardown

    override func setUp() {
        super.setUp()

        module = SplunkAppStart.AppStart()

        if let module {
            moduleProxy = SplunkAgent.AppStart(for: module)
        }
    }

    override func tearDown() {
        super.tearDown()

        module = nil
        moduleProxy = nil
    }


    // MARK: - Manual tracking

    func testManualTracking() throws {
        let moduleProxy = try XCTUnwrap(moduleProxy)

        XCTAssertNotNil(moduleProxy.track(didBecomeActive: Date(), didFinishLaunching: Date(), willEnterForeground: Date()))
        XCTAssertNotNil(moduleProxy.track(didBecomeActive: Date(), didFinishLaunching: nil, willEnterForeground: nil))
    }
}
