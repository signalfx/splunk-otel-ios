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

import Foundation
import XCTest
@testable import SplunkNetwork

final class NetworkConfigurationTests: XCTestCase {

    // MARK: - NetworkInstrumentationConfiguration Tests

    func testNetworkInstrumentationConfiguration_DefaultInit() {
        let config = NetworkInstrumentationConfiguration(isEnabled: true, ignoreURLs: nil)

        XCTAssertTrue(config.isEnabled)
        XCTAssertNil(config.ignoreURLs)
    }

    func testNetworkInstrumentationConfiguration_WithIgnoreURLs() throws {
        let patterns = Set([".*\\.(jpg|jpeg|png|gif)$"])
        let ignoreURLs = try IgnoreURLs(patterns: patterns)

        let config = NetworkInstrumentationConfiguration(isEnabled: true, ignoreURLs: ignoreURLs)

        XCTAssertTrue(config.isEnabled)
        XCTAssertNotNil(config.ignoreURLs)
        XCTAssertEqual(config.ignoreURLs?.count(), 1)
    }

    func testNetworkInstrumentationConfiguration_Disabled() {
        let config = NetworkInstrumentationConfiguration(isEnabled: false, ignoreURLs: nil)

        XCTAssertFalse(config.isEnabled)
        XCTAssertNil(config.ignoreURLs)
    }
}
