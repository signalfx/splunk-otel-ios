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

@testable import SplunkAgent
import XCTest

final class AppInfoTests: XCTestCase {

    func testValues() throws {

        // Name
        let name = try XCTUnwrap(AppInfo.name)
        XCTAssertFalse(name.isEmpty)

        // Bundle ID
        let bundleID = try XCTUnwrap(AppInfo.bundleId)
        XCTAssertFalse(bundleID.isEmpty)

        // Version
        let version = try XCTUnwrap(AppInfo.version)
        XCTAssertFalse(version.isEmpty)

        // Build
        let build = try XCTUnwrap(AppInfo.buildId)
        XCTAssertFalse(build.isEmpty)
    }
}
