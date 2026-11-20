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

@testable import SplunkAgent

final class CustomTrackingProxyTests: XCTestCase {

    // MARK: - Configuration

    func testDisabledConfigurationUsesNonOperationalProxy() throws {
        let configuration = try ConfigurationTestBuilder.buildDefault()
        let agent = try SplunkRum(
            with: configuration,
            moduleConfigurations: [
                CustomTrackingConfiguration(isEnabled: false)
            ]
        )

        XCTAssertTrue(agent.customTrackingProxy is CustomTrackingNonOperational)
        XCTAssertTrue(agent.customTracking is CustomTrackingNonOperational)
    }
}
