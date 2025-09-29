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

@testable import SplunkNetworkMonitor

final class NetworkMonitorConfigurationTests: XCTestCase {

    // MARK: - NetworkMonitor Configuration Tests

    func testNetworkMonitorConfigurationInitialization() {
        let config = NetworkMonitorConfiguration(isEnabled: true)
        XCTAssertTrue(config.isEnabled)

        let disabledConfig = NetworkMonitorConfiguration(isEnabled: false)
        XCTAssertFalse(disabledConfig.isEnabled)
    }

    func testNetworkMonitorConfigurationDefaultValue() {
        let config = NetworkMonitorConfiguration(isEnabled: true)
        XCTAssertTrue(config.isEnabled)
    }

    // MARK: - NetworkMonitorRemoteConfiguration Tests

    func testNetworkMonitorRemoteConfigurationValidJSON() {
        let jsonString = """
            {
                "configuration": {
                    "mrum": {
                        "networkMonitor": {
                            "enabled": true
                        }
                    }
                }
            }
            """

        let jsonData = Data(jsonString.utf8)
        let config = NetworkMonitorRemoteConfiguration(from: jsonData)

        XCTAssertNotNil(config)
        XCTAssertTrue(config?.enabled == true)
    }

    func testNetworkMonitorRemoteConfigurationDisabled() {
        let jsonString = """
            {
                "configuration": {
                    "mrum": {
                        "networkMonitor": {
                            "enabled": false
                        }
                    }
                }
            }
            """

        let jsonData = Data(jsonString.utf8)
        let config = NetworkMonitorRemoteConfiguration(from: jsonData)

        XCTAssertNotNil(config)
        XCTAssertTrue(config?.enabled == false)
    }

    func testNetworkMonitorRemoteConfigurationInvalidJSON() {
        let invalidJSON = Data("invalid json".utf8)
        let config = NetworkMonitorRemoteConfiguration(from: invalidJSON)

        XCTAssertNil(config)
    }

    func testNetworkMonitorRemoteConfigurationMissingFields() {
        let jsonString = """
            {
                "configuration": {
                    "mrum": {
                        "networkMonitor": {
                        }
                    }
                }
            }
            """

        let jsonData = Data(jsonString.utf8)
        let config = NetworkMonitorRemoteConfiguration(from: jsonData)

        XCTAssertNil(config)
    }
}
