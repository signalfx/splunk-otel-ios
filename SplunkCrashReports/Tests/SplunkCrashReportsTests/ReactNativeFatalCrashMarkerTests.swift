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

@testable import SplunkCrashReports

final class ReactNativeFatalCrashMarkerTests: XCTestCase {
    func testFreshEmbeddedMarkerSuppressesNativeDuplicate() throws {
        let crashReports = CrashReports()
        let armedAt = Date(timeIntervalSince1970: 1_000)
        let customData = try archiveMarker(armedAt: armedAt)

        XCTAssertTrue(
            crashReports.shouldSuppressReactNativeFatalCrash(
                customData: customData,
                crashTimestamp: armedAt.addingTimeInterval(1.5)
            )
        )
    }

    func testExpiredEmbeddedMarkerFailsOpen() throws {
        let crashReports = CrashReports()
        let armedAt = Date(timeIntervalSince1970: 1_000)
        let customData = try archiveMarker(armedAt: armedAt)

        XCTAssertFalse(
            crashReports.shouldSuppressReactNativeFatalCrash(
                customData: customData,
                crashTimestamp: armedAt.addingTimeInterval(2.01)
            )
        )
    }

    func testWholeSecondCrashTimestampSuppressesMarkerCreatedLaterInSameSecond() throws {
        let crashReports = CrashReports()
        let armedAt = Date(timeIntervalSince1970: 1_000.315)
        let customData = try archiveMarker(armedAt: armedAt)

        // PLCrashReporter truncates this timestamp to the beginning of the
        // second, even though the native crash followed the marker.
        XCTAssertTrue(
            crashReports.shouldSuppressReactNativeFatalCrash(
                customData: customData,
                crashTimestamp: Date(timeIntervalSince1970: 1_000)
            )
        )
    }

    func testMarkerBeyondTimestampResolutionAndClockSkewFailsOpen() throws {
        let crashReports = CrashReports()
        let armedAt = Date(timeIntervalSince1970: 1_001.251)
        let customData = try archiveMarker(armedAt: armedAt)

        XCTAssertFalse(
            crashReports.shouldSuppressReactNativeFatalCrash(
                customData: customData,
                crashTimestamp: Date(timeIntervalSince1970: 1_000)
            )
        )
    }

    func testInvalidSpanIdFailsOpen() throws {
        let crashReports = CrashReports()
        let armedAt = Date(timeIntervalSince1970: 1_000)
        let customData = try archiveMarker(armedAt: armedAt, spanId: "not-a-span-id")

        XCTAssertFalse(
            crashReports.shouldSuppressReactNativeFatalCrash(
                customData: customData,
                crashTimestamp: armedAt.addingTimeInterval(0.1)
            )
        )
    }

    func testArmingPublishesMarkerToPLCrashReporterCustomData() throws {
        let crashReports = CrashReports()
        crashReports.configureCrashReporter()
        let armedAt = Date()

        XCTAssertTrue(
            crashReports.armReactNativeFatalMarker(
                spanId: "0123456789abcdef",
                armedAt: armedAt
            )
        )

        let customData = try XCTUnwrap(crashReports.crashReporter?.customData)
        XCTAssertTrue(
            crashReports.shouldSuppressReactNativeFatalCrash(
                customData: customData,
                crashTimestamp: armedAt.addingTimeInterval(0.1)
            )
        )
    }

    private func archiveMarker(
        armedAt: Date,
        spanId: String = "0123456789abcdef"
    ) throws -> Data {
        let dictionary = [
            CrashReportCustomDataKeys.reactNativeFatalSchema.rawValue:
                ReactNativeFatalMarkerConstants.schema,
            CrashReportCustomDataKeys.reactNativeFatalSpanId.rawValue: spanId,
            CrashReportCustomDataKeys.reactNativeFatalArmedAtEpochMs.rawValue:
                String(Int64(armedAt.timeIntervalSince1970 * 1_000))
        ]
        return try NSKeyedArchiver.archivedData(
            withRootObject: dictionary,
            requiringSecureCoding: false
        )
    }
}
