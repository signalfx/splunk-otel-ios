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

final class NetworkMonitorDestinationTests: XCTestCase {

    func testOTelDestination() {
        let destination = OTelDestination()
        let event = NetworkMonitorEvent(
            timestamp: Date(),
            isConnected: true,
            connectionType: .wifi,
            radioType: nil
        )

        // This should not crash and should execute without errors
        destination.send(networkEvent: event, sharedState: nil)
    }

    func testDebugDestination() {
        let destination = DebugDestination()
        let event = NetworkMonitorEvent(
            timestamp: Date(),
            isConnected: true,
            connectionType: .cellular,
            radioType: "LTE (4G)"
        )

        // This should not crash and should execute without errors
        destination.send(networkEvent: event, sharedState: nil)
    }

    func testDebugDestinationWithNilRadioType() {
        let destination = DebugDestination()
        let event = NetworkMonitorEvent(
            timestamp: Date(),
            isConnected: false,
            connectionType: .wifi,
            radioType: nil
        )

        // This should not crash and should execute without errors
        destination.send(networkEvent: event, sharedState: nil)
    }
}
