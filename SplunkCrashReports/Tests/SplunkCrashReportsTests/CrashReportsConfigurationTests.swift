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

@testable import SplunkCommon
@testable import SplunkCrashReports

final class CrashReportsConfigurationTests: XCTestCase {

    func testConfigurationEnabledByDefault() {
        let config = CrashReportsConfiguration(isEnabled: true)

        XCTAssertTrue(config.isEnabled)
    }

    func testConfigurationCanBeDisabled() {
        let config = CrashReportsConfiguration(isEnabled: false)

        XCTAssertFalse(config.isEnabled)
    }

    func testConfigurationConformsToModuleConfiguration() {
        // Compile-time conformance: this assignment fails to build if the protocol is not satisfied.
        let config: any ModuleConfiguration = CrashReportsConfiguration(isEnabled: true)

        XCTAssertNotNil(config)
    }

    func testDefaultPropertyValueIsTrue() {
        var config = CrashReportsConfiguration(isEnabled: false)

        // Reset to the struct's declared default
        config.isEnabled = true

        XCTAssertTrue(config.isEnabled)
    }

    func testConfigurationIsValueType() {
        let original = CrashReportsConfiguration(isEnabled: true)
        var copy = original
        copy.isEnabled = false

        XCTAssertTrue(original.isEnabled)
        XCTAssertFalse(copy.isEnabled)
    }
}
