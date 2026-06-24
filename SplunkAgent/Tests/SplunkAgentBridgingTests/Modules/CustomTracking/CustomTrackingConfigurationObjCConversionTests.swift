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

import SplunkCustomTracking
import XCTest

@testable import SplunkAgentObjC

/// Verifies that ``CustomTrackingConfigurationObjC`` correctly converts into
/// ``SplunkCustomTracking/CustomTrackingConfiguration``.
final class CustomTrackingConfigObjCConversionTests: XCTestCase {

    // MARK: - Helpers

    private func convert(_ config: CustomTrackingConfigurationObjC) -> CustomTrackingConfiguration? {
        config.moduleConfiguration as? CustomTrackingConfiguration
    }


    // MARK: - Property forwarding

    func testIncludeBinaryImagesOnErrorsDefaultsToEnabled() {
        let config = CustomTrackingConfigurationObjC()

        let result = convert(config)

        XCTAssertEqual(result?.includeBinaryImagesOnErrors, true)
    }

    func testIncludeBinaryImagesOnErrorsOptOutForwarded() {
        let config = CustomTrackingConfigurationObjC(
            isEnabled: true,
            includeBinaryImagesOnErrors: false
        )

        let result = convert(config)

        XCTAssertEqual(result?.includeBinaryImagesOnErrors, false)
    }
}
