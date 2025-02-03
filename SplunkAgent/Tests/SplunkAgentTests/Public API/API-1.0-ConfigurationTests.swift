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

import SplunkAgent
import XCTest

final class API10ConfigurationTests: XCTestCase {

    // MARK: - Private

    private let endpointUrl = ConfigurationTestBuilder.endpointUrl!


    // MARK: - API Tests

    func testConfiguration() throws {
        // Default initialization
        var full = try ConfigurationTestBuilder.buildDefault()

        // Properties (READ)
        XCTAssertEqual(full.url, endpointUrl)
        XCTAssertNotNil(full.appName)
        XCTAssertNotNil(full.appVersion)


        // Minimal initialization
        let minimal = Configuration(url: endpointUrl)
        XCTAssertNotNil(minimal)

        // Properties (READ)
        XCTAssertNotNil(minimal.appName)
        XCTAssertNotNil(minimal.appVersion)

        // Properties (WRITE)

        let appName = "Test Application Name"
        full.appName = appName
        XCTAssertEqual(full.appName, appName)

        let appVersion = "0.0.1 Test"
        full.appVersion = appVersion
        XCTAssertEqual(full.appVersion, appVersion)
    }

    func testConfigurationBuilder() throws {
        let appName = "Test Application Name"
        let appVersion = "0.0.1 Test"

        // Builder methods
        let configuration = Configuration(url: endpointUrl)
            .appName(appName)
            .appVersion(appVersion)

        // Check if the data has been written
        XCTAssertEqual(configuration.appName, appName)
        XCTAssertEqual(configuration.appVersion, appVersion)
    }
}
