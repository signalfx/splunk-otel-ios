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

import CoreTelephony
import Foundation
import Network
import XCTest
@testable import SplunkNetworkMonitor

final class NetworkMonitorTests: XCTestCase {

    // MARK: - Private

    private var networkMonitor: NetworkMonitor?


    // MARK: - Tests lifecycle

    override func setUpWithError() throws {
        super.setUp()

        networkMonitor = NetworkMonitor()
    }

    override func tearDownWithError() throws {
        networkMonitor?.stopDetection()
        networkMonitor = nil

        super.tearDown()
    }


    // MARK: - ConnectionType Tests

    func testConnectionTypeRawValues() {
        XCTAssertEqual(ConnectionType.wifi.rawValue, "wifi")
        XCTAssertEqual(ConnectionType.cellular.rawValue, "cellular")
        XCTAssertEqual(ConnectionType.wiredEthernet.rawValue, "wiredEthernet")
        XCTAssertEqual(ConnectionType.vpn.rawValue, "vpn")
        XCTAssertEqual(ConnectionType.other.rawValue, "other")
        XCTAssertEqual(ConnectionType.unavailable.rawValue, "unavailable")
    }


    // MARK: - NetworkMonitor Module Tests

    func testNetworkMonitorMetadata() {
        let metadata = NetworkMonitorMetadata()

        XCTAssertEqual(metadata.eventName, "network.change")
        XCTAssertNotNil(metadata.timestamp)
    }

    func testNetworkMonitorData() {
        let data = NetworkMonitorData()
        // NetworkMonitorData is empty, just verify it can be created
        XCTAssertNotNil(data)
    }


    // MARK: - NetworkMonitor Status Change Handler Tests

    func testNetworkMonitorStatusChangeHandler() throws {
        let networkMonitor = try XCTUnwrap(networkMonitor)

        var handlerCalled = false
        var receivedIsConnected = false
        var receivedConnectionType: ConnectionType = .unavailable
        var receivedRadioType: String?

        networkMonitor.statusChangeHandler = { isConnected, connectionType, radioType in
            handlerCalled = true
            receivedIsConnected = isConnected
            receivedConnectionType = connectionType
            receivedRadioType = radioType
        }

        // Simulate a network change by directly calling the handler
        networkMonitor.statusChangeHandler?(true, .wifi, nil)

        XCTAssertTrue(handlerCalled)
        XCTAssertTrue(receivedIsConnected)
        XCTAssertEqual(receivedConnectionType, .wifi)
        XCTAssertNil(receivedRadioType)
    }
}
