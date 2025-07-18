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
import Foundation
import Network
import CoreTelephony

@testable import SplunkNetworkMonitor

final class NetworkMonitorTests: XCTestCase {

    var networkMonitor: NetworkMonitor!

    override func setUpWithError() throws {
        super.setUp()
        networkMonitor = NetworkMonitor()
    }

    override func tearDownWithError() throws {
        networkMonitor.stopDetection()
        networkMonitor = nil
        super.tearDown()
    }

    // MARK: - NetworkMonitorEvent Tests

    func testNetworkMonitorEventInitialization() {
        let timestamp = Date()
        let event = NetworkMonitorEvent(
            timestamp: timestamp,
            isConnected: true,
            connectionType: .wifi,
            radioType: nil
        )

        XCTAssertEqual(event.timestamp, timestamp)
        XCTAssertTrue(event.isConnected)
        XCTAssertEqual(event.connectionType, .wifi)
        XCTAssertNil(event.radioType)
    }

    func testNetworkMonitorEventWithRadioType() {
        let event = NetworkMonitorEvent(
            timestamp: Date(),
            isConnected: true,
            connectionType: .cellular,
            radioType: "LTE (4G)"
        )

        XCTAssertTrue(event.isConnected)
        XCTAssertEqual(event.connectionType, .cellular)
        XCTAssertEqual(event.radioType, "LTE (4G)")
    }

    // MARK: - NetworkMonitorEvent Comparison Tests

    func testNetworkMonitorEventIsDifferent_WhenEventsAreDifferent() {
        let event1 = NetworkMonitorEvent(
            timestamp: Date(),
            isConnected: true,
            connectionType: .wifi,
            radioType: nil
        )

        let event2 = NetworkMonitorEvent(
            timestamp: Date().addingTimeInterval(1),
            isConnected: false,
            connectionType: .cellular,
            radioType: "LTE (4G)"
        )

        XCTAssertTrue(event1.isDifferent(from: event2))
    }

    func testNetworkMonitorEventIsDifferent_WhenEventsAreSame() {
        let event1 = NetworkMonitorEvent(
            timestamp: Date(),
            isConnected: true,
            connectionType: .wifi,
            radioType: nil
        )

        let event2 = NetworkMonitorEvent(
            timestamp: Date().addingTimeInterval(1),
            isConnected: true,
            connectionType: .wifi,
            radioType: nil
        )

        XCTAssertFalse(event1.isDifferent(from: event2))
    }

    func testNetworkMonitorEventIsDifferent_WhenEventsAreCloseInTime() {
        let event1 = NetworkMonitorEvent(
            timestamp: Date(),
            isConnected: true,
            connectionType: .wifi,
            radioType: nil
        )

        let event2 = NetworkMonitorEvent(
            timestamp: Date().addingTimeInterval(0.002), // 2ms apart
            isConnected: false,
            connectionType: .cellular,
            radioType: "LTE (4G)"
        )

        // Should return false even though properties are different due to time proximity
        XCTAssertFalse(event1.isDifferent(from: event2))
    }

    func testNetworkMonitorEventIsDifferent_WhenEventsAreFarApartInTime() {
        let event1 = NetworkMonitorEvent(
            timestamp: Date(),
            isConnected: true,
            connectionType: .wifi,
            radioType: nil
        )

        let event2 = NetworkMonitorEvent(
            timestamp: Date().addingTimeInterval(0.005), // 5ms apart
            isConnected: false,
            connectionType: .cellular,
            radioType: "LTE (4G)"
        )

        // Should return true since events are far enough apart and properties are different
        XCTAssertTrue(event1.isDifferent(from: event2))
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

        let jsonData = jsonString.data(using: .utf8)!
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

        let jsonData = jsonString.data(using: .utf8)!
        let config = NetworkMonitorRemoteConfiguration(from: jsonData)

        XCTAssertNotNil(config)
        XCTAssertTrue(config?.enabled == false)
    }

    func testNetworkMonitorRemoteConfigurationInvalidJSON() {
        let invalidJSON = "invalid json".data(using: .utf8)!
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

        let jsonData = jsonString.data(using: .utf8)!
        let config = NetworkMonitorRemoteConfiguration(from: jsonData)

        XCTAssertNil(config)
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

    func testNetworkMonitorStatusChangeHandler() {
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

// MARK: - Destination Tests

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

// MARK: - Edge Cases and Error Handling

final class NetworkMonitorEdgeCaseTests: XCTestCase {

    func testNetworkMonitorEventWithAllConnectionTypes() {
        let connectionTypes: [ConnectionType] = [.wifi, .cellular, .wiredEthernet, .vpn, .other, .unavailable]

        for connectionType in connectionTypes {
            let event = NetworkMonitorEvent(
                timestamp: Date(),
                isConnected: true,
                connectionType: connectionType,
                radioType: nil
            )

            XCTAssertEqual(event.connectionType, connectionType)
            XCTAssertTrue(event.isConnected)
        }
    }

    func testNetworkMonitorEventWithVariousRadioTypes() {
        let radioTypes = ["GPRS (2G)", "EDGE (2G)", "WCDMA (3G)", "LTE (4G)", "NR (5G Standalone)", nil]

        for radioType in radioTypes {
            let event = NetworkMonitorEvent(
                timestamp: Date(),
                isConnected: true,
                connectionType: .cellular,
                radioType: radioType
            )

            XCTAssertEqual(event.radioType, radioType)
        }
    }

    func testNetworkMonitorEventComparisonWithSameTimestamp() {
        let timestamp = Date()
        let event1 = NetworkMonitorEvent(
            timestamp: timestamp,
            isConnected: true,
            connectionType: .wifi,
            radioType: nil
        )

        let event2 = NetworkMonitorEvent(
            timestamp: timestamp,
            isConnected: true,
            connectionType: .wifi,
            radioType: nil
        )

        // Should return false since they're identical
        XCTAssertFalse(event1.isDifferent(from: event2))
    }

    func testNetworkMonitorEventComparisonWithDifferentRadioTypes() {
        let event1 = NetworkMonitorEvent(
            timestamp: Date(),
            isConnected: true,
            connectionType: .cellular,
            radioType: "LTE (4G)"
        )

        let event2 = NetworkMonitorEvent(
            timestamp: Date().addingTimeInterval(0.005),
            isConnected: true,
            connectionType: .cellular,
            radioType: "NR (5G Standalone)"
        )

        // Should return true since radio types are different
        XCTAssertTrue(event1.isDifferent(from: event2))
    }

    func testNetworkMonitorEventComparisonWithNilVsNonNilRadioType() {
        let event1 = NetworkMonitorEvent(
            timestamp: Date(),
            isConnected: true,
            connectionType: .cellular,
            radioType: nil
        )

        let event2 = NetworkMonitorEvent(
            timestamp: Date().addingTimeInterval(0.005),
            isConnected: true,
            connectionType: .cellular,
            radioType: "LTE (4G)"
        )

        // Should return true since one has radio type and the other doesn't
        XCTAssertTrue(event1.isDifferent(from: event2))
    }
}

// MARK: - Performance Tests

final class NetworkMonitorPerformanceTests: XCTestCase {

    func testNetworkMonitorEventComparisonPerformance() {
        let event1 = NetworkMonitorEvent(
            timestamp: Date(),
            isConnected: true,
            connectionType: .wifi,
            radioType: nil
        )

        let event2 = NetworkMonitorEvent(
            timestamp: Date().addingTimeInterval(0.005),
            isConnected: false,
            connectionType: .cellular,
            radioType: "LTE (4G)"
        )

        measure {
            for _ in 0..<1000 {
                _ = event1.isDifferent(from: event2)
            }
        }
    }

    func testNetworkMonitorEventCreationPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = NetworkMonitorEvent(
                    timestamp: Date(),
                    isConnected: true,
                    connectionType: .wifi,
                    radioType: nil
                )
            }
        }
    }
}
