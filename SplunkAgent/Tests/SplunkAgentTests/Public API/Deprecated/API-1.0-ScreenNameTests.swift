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

final class API10ScreenNameTests: XCTestCase {

    // MARK: - Private

    var agent: SplunkRum?


    // MARK: - Tests lifecycle

    override func setUp() {
        super.setUp()

        agent = nil
    }

    override func tearDown() {
        SplunkRum.resetSharedInstance()

        super.tearDown()
    }


    // MARK: - API Tests

    func testScreenNameMethods() throws {
        let screenName = "Test"
        let screenNameChangeCallback: ((String) -> Void)? = { _ in
            // Not used
        }

        // Access the relevant methods indirectly through
        // the protocol for deprecated interface.
        SplunkRum.deprecatedSetScreenName(screenName)

        SplunkRum.deprecatedAddScreenNameChangeCallback(screenNameChangeCallback)
        SplunkRum.deprecatedAddScreenNameChangeCallback(nil)
    }

    func testBusinessLogic() throws {
        let expectation = XCTestExpectation(description: "Delayed execution")

        // Agent install
        let configuration = try ConfigurationTestBuilder.buildDefault()
        agent = try SplunkRum.install(with: configuration)

        // Screen name change handling
        let screenName = "Test"
        let screenNameChangeCallback: ((String) -> Void)? = { name in
            if name == screenName {
                expectation.fulfill()
            }
        }

        // Access the relevant methods indirectly through
        // the protocol for deprecated interface.
        SplunkRum.deprecatedAddScreenNameChangeCallback(screenNameChangeCallback)

        // Change screen name
        SplunkRum.deprecatedSetScreenName(screenName)

        wait(for: [expectation], timeout: 1)
    }
}
