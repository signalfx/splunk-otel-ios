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

@testable import CiscoRUM
import XCTest

final class SystemInfoTests: XCTestCase {

    func testValues() throws {

        // Name
        let name = SystemInfo.name
        XCTAssertFalse(name.isEmpty)

        // Version
        let version = try XCTUnwrap(SystemInfo.version)
        XCTAssertFalse(version.isEmpty)

        // OS description
        let osDescription = SystemInfo.description
        XCTAssertFalse(osDescription.isEmpty)

        // OS type
        let osType = SystemInfo.type
        XCTAssertFalse(osType.isEmpty)
    }
}
