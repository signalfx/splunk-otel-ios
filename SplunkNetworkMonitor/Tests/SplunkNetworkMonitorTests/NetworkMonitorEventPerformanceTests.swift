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

final class NetworkMonitorEventPerformanceTests: XCTestCase {

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
            for _ in 0 ..< 1_000 {
                _ = event1.isDebouncedChange(from: event2)
            }
        }
    }

    func testNetworkMonitorEventCreationPerformance() {
        measure {
            for _ in 0 ..< 1_000 {
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
