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

final class DeviceInfoTests: XCTestCase {

    func testValues() throws {

        // Type
        let type = try XCTUnwrap(DeviceInfo.type)
        XCTAssertFalse(type.isEmpty)

        // Platform
        let platform = DeviceInfo.platform
        XCTAssertFalse(platform.isEmpty)

        // Architecture
        let architecture = try XCTUnwrap(DeviceInfo.architecture)
        XCTAssertFalse(architecture.isEmpty)
    }
}
