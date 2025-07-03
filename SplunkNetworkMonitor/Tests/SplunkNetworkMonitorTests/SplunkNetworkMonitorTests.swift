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

import Network
@testable import SplunkNetworkMonitor
import XCTest

final class NetworkMonitorTests: XCTestCase {
    func testInitialState() {
        let NetworkMonitor = NetworkMonitor()
        XCTAssertFalse(NetworkMonitor.isConnected)
        XCTAssertEqual(NetworkMonitor.connectionType, .unavailable)
    }

    func testNetworkMonitoring() {
        let NetworkMonitor = NetworkMonitor()
        let exp = expectation(description: "Network status change")

        // Set up handler to verify network changes
        NetworkMonitor.statusChangeHandler = { isConnected, type in
            // Just verify we got a callback
            exp.fulfill()
        }

        // Start monitoring
        NetworkMonitor.startDetection()

        wait(for: [exp], timeout: 5.0)
    }
}
