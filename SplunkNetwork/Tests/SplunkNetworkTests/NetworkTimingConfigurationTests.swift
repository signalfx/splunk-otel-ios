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

import Foundation
import XCTest

@testable import SplunkNetwork

// MARK: - Configuration Tests

final class NetworkTimingConfigurationTests: XCTestCase {

    func testDefaultConfigHasTimingEnabled() {
        let config = NetworkInstrumentationConfiguration()

        XCTAssertTrue(config.collectNetworkTiming)
    }

    func testConfigWithTimingDisabled() {
        let config = NetworkInstrumentationConfiguration(collectNetworkTiming: false)

        XCTAssertFalse(config.collectNetworkTiming)
        XCTAssertTrue(config.isEnabled)
        XCTAssertTrue(config.injectTraceHeaders)
    }

    func testFullConfigPreservesAllParameters() throws {
        let ignoreURLs = try IgnoreURLs(patterns: Set([".*\\.png$"]))

        let config = NetworkInstrumentationConfiguration(
            isEnabled: false,
            ignoreURLs: ignoreURLs,
            injectTraceHeaders: false,
            collectNetworkTiming: false
        )

        XCTAssertFalse(config.isEnabled)
        XCTAssertNotNil(config.ignoreURLs)
        XCTAssertFalse(config.injectTraceHeaders)
        XCTAssertFalse(config.collectNetworkTiming)
    }

    func testModuleStoresTimingFlag() {
        let module = NetworkInstrumentation()

        let config = NetworkInstrumentationConfiguration(collectNetworkTiming: true)
        module.install(with: config, remoteConfiguration: nil)

        XCTAssertTrue(module.isNetworkTimingEnabled)

        addTeardownBlock {
            module.uninstall()
        }
    }

    func testModuleDefaultsTimingToEnabled() {
        let module = NetworkInstrumentation()

        module.install(with: nil, remoteConfiguration: nil)

        XCTAssertTrue(module.isNetworkTimingEnabled)

        addTeardownBlock {
            module.uninstall()
        }
    }
}
