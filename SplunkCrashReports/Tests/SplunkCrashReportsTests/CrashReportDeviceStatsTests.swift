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

@testable import SplunkCrashReports

final class CrashReportDeviceStatsTests: XCTestCase {

    // MARK: - Battery Level Tests

    func testDeviceStats_BatteryLevel_ReturnsNonEmptyString() {
        let batteryLevel = CrashReportDeviceStats.batteryLevel

        XCTAssertFalse(batteryLevel.isEmpty)
    }

    func testDeviceStats_BatteryLevel_HasValidFormat() {
        let batteryLevel = CrashReportDeviceStats.batteryLevel

        #if !os(tvOS)
        // On iOS, should contain a percentage value
        XCTAssertTrue(
            batteryLevel.contains("%") || batteryLevel == "Unknown",
            "Battery level should contain % or be Unknown, got: \(batteryLevel)"
        )
        #else
        // On tvOS, should be "Unknown"
        XCTAssertEqual(batteryLevel, "Unknown")
        #endif
    }

    // MARK: - Free Disk Space Tests

    func testDeviceStats_FreeDiskSpace_ReturnsNonEmptyString() {
        let freeDiskSpace = CrashReportDeviceStats.freeDiskSpace

        XCTAssertFalse(freeDiskSpace.isEmpty)
    }

    func testDeviceStats_FreeDiskSpace_HasValidFormat() {
        let freeDiskSpace = CrashReportDeviceStats.freeDiskSpace

        // Should contain bytes unit (KB, MB, GB, TB) or be "Unknown"
        let containsUnit =
            freeDiskSpace.contains("KB") ||
            freeDiskSpace.contains("MB") ||
            freeDiskSpace.contains("GB") ||
            freeDiskSpace.contains("TB") ||
            freeDiskSpace.contains("bytes") ||
            freeDiskSpace == "Unknown"

        XCTAssertTrue(
            containsUnit,
            "Free disk space should contain a unit or be Unknown, got: \(freeDiskSpace)"
        )
    }

    // MARK: - Free Memory Tests

    func testDeviceStats_FreeMemory_ReturnsNonEmptyString() {
        let freeMemory = CrashReportDeviceStats.freeMemory

        XCTAssertFalse(freeMemory.isEmpty)
    }

    func testDeviceStats_FreeMemory_HasValidFormat() {
        let freeMemory = CrashReportDeviceStats.freeMemory

        // Should contain bytes unit (KB, MB, GB) or be "Unknown"
        let containsUnit =
            freeMemory.contains("KB") ||
            freeMemory.contains("MB") ||
            freeMemory.contains("GB") ||
            freeMemory.contains("bytes") ||
            freeMemory == "Unknown"

        XCTAssertTrue(
            containsUnit,
            "Free memory should contain a unit or be Unknown, got: \(freeMemory)"
        )
    }

    // MARK: - Multiple Calls Tests

    func testDeviceStats_MultipleCallsToSameProperty_ReturnConsistentFormat() {
        let batteryLevel1 = CrashReportDeviceStats.batteryLevel
        let batteryLevel2 = CrashReportDeviceStats.batteryLevel

        // Both should have same format (both with % or both Unknown)
        let format1 = batteryLevel1.contains("%") ? "percentage" : "unknown"
        let format2 = batteryLevel2.contains("%") ? "percentage" : "unknown"

        XCTAssertEqual(format1, format2)
    }

    func testDeviceStats_AllPropertiesAccessible() {
        // Verify all properties can be accessed without crashing
        _ = CrashReportDeviceStats.batteryLevel
        _ = CrashReportDeviceStats.freeDiskSpace
        _ = CrashReportDeviceStats.freeMemory

        // If we reach here, all properties are accessible
        XCTAssertTrue(true)
    }
}
