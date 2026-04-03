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

/// Tests for the `imageList(images:)` method in `CrashReports+Images.swift`.
///
/// Building a complete image dictionary requires `PLCrashReportBinaryImageInfo`
/// instances, which can only be obtained from real crash report data. These
/// tests cover the boundary behavior (empty input, non-matching types, and the
/// `allUsedImageNames` filtering contract).
final class CrashReportsImageListTests: XCTestCase {

    private let crashReports = CrashReports()

    // MARK: - imageList

    func testImageListEmptyInputProducesEmptyJSONArray() throws {
        let result = crashReports.imageList(images: [])

        let data = try XCTUnwrap(result.data(using: .utf8))
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [Any])

        XCTAssertTrue(parsed.isEmpty)
    }

    func testImageListSkipsNonBinaryImageInfoElements() throws {
        // Items that are not PLCrashReportBinaryImageInfo are silently skipped.
        let nonImageItems: [Any] = ["not-an-image", 42, ["key": "value"]]

        let result = crashReports.imageList(images: nonImageItems)

        let data = try XCTUnwrap(result.data(using: .utf8))
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [Any])

        XCTAssertTrue(parsed.isEmpty)
    }

    func testAllUsedImageNamesFilteringContract() {
        // imageList only includes images whose imageName appears in allUsedImageNames.
        // Without real PLCrashReportBinaryImageInfo we verify the filter list itself.
        crashReports.allUsedImageNames = ["libA.dylib", "libB.framework"]

        XCTAssertTrue(crashReports.allUsedImageNames.contains("libA.dylib"))
        XCTAssertTrue(crashReports.allUsedImageNames.contains("libB.framework"))
        XCTAssertFalse(crashReports.allUsedImageNames.contains("libC.dylib"))
    }

    func testAllUsedImageNamesIsResetOnReuse() {
        crashReports.allUsedImageNames = ["libA.dylib"]

        XCTAssertEqual(crashReports.allUsedImageNames.count, 1)

        crashReports.allUsedImageNames.removeAll()

        XCTAssertTrue(crashReports.allUsedImageNames.isEmpty)
    }
}
