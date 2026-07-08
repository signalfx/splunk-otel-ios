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

import XCTest

@testable import SplunkCommon
@testable import SplunkCustomTracking

final class CustomTrackingConfigurationTests: XCTestCase {

    // MARK: - Configuration

    func testConfigurationDefaultsToEnabled() {
        let configuration = CustomTrackingConfiguration()

        XCTAssertTrue(configuration.isEnabled)
        XCTAssertTrue(configuration.includeBinaryImagesOnErrors)
    }

    func testDisabledConfigurationSuppressesCustomEvents() {
        let module = CustomTrackingInternal()
        let expectation = expectation(description: "Custom event should not be published")
        expectation.isInverted = true

        module.install(
            with: CustomTrackingConfiguration(isEnabled: false),
            remoteConfiguration: nil
        )
        module.onPublish { _, _ in
            expectation.fulfill()
        }

        module.track(SplunkTrackableEvent(eventName: "disabled", attributes: [:]))

        wait(for: [expectation], timeout: 0.1)
    }

    func testDisabledConfigurationSuppressesCustomErrors() {
        let module = CustomTrackingInternal()
        let expectation = expectation(description: "Custom error should not be published")
        expectation.isInverted = true

        module.install(
            with: CustomTrackingConfiguration(isEnabled: false),
            remoteConfiguration: nil
        )
        module.onPublish { _, _ in
            expectation.fulfill()
        }

        module.track(SplunkIssue(from: "disabled"), [:])

        wait(for: [expectation], timeout: 0.1)
    }
}
