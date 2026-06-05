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

@_spi(SplunkTesting) import SplunkAgentObjC
import SplunkLifecycle
import XCTest

final class LifecycleObjCConversionTests: XCTestCase {

    // MARK: - Helpers

    private func convert(_ configuration: LifecycleConfigurationObjC) -> LifecycleConfiguration? {
        configuration.splunkTestingModuleConfiguration as? LifecycleConfiguration
    }


    // MARK: - Defaults

    func testDefaultConfigurationConvertsToSwiftDefault() {
        let configuration = LifecycleConfigurationObjC()

        let result = convert(configuration)

        XCTAssertEqual(result?.isEnabled, true)
        XCTAssertEqual(result?.allowedEvents, LifecycleAction.mainLifecycleEvents)
    }


    // MARK: - Property forwarding

    func testIsEnabledForwarded() {
        let configuration = LifecycleConfigurationObjC(isEnabled: false)

        let result = convert(configuration)

        XCTAssertEqual(result?.isEnabled, false)
    }

    func testAllowedEventsForwarded() {
        let configuration = LifecycleConfigurationObjC(
            isEnabled: true,
            allowedEvents: [LifecycleActionObjC.viewCreated as String]
        )

        let result = convert(configuration)

        XCTAssertEqual(result?.allowedEvents, [.viewCreated])
    }


    // MARK: - Unknown string behavior

    func testSupportedStringsConvertToLifecycleActions() {
        let configuration = LifecycleConfigurationObjC(
            allowedEvents: [
                LifecycleActionObjC.viewCreated as String,
                LifecycleActionObjC.resumed as String,
                LifecycleActionObjC.stopped as String
            ]
        )

        let result = convert(configuration)

        XCTAssertEqual(result?.allowedEvents, [.viewCreated, .resumed, .stopped])
    }

    func testAndroidMainLifecycleEventsDropUnsupportedStrings() {
        let androidMainLifecycleEvents = [
            "created",
            "started",
            "resumed",
            "paused",
            "stopped",
            "destroyed",
            "attached",
            "view_created",
            "view_destroyed",
            "detached"
        ]
        let configuration = LifecycleConfigurationObjC(
            allowedEvents: androidMainLifecycleEvents
        )

        let result = convert(configuration)

        XCTAssertEqual(result?.allowedEvents, [.viewCreated, .resumed, .stopped])
    }

    func testMixedSupportedAndUnsupportedStringsDropUnsupportedStrings() {
        let configuration = LifecycleConfigurationObjC(
            allowedEvents: [
                LifecycleActionObjC.viewCreated as String,
                "started",
                "paused"
            ]
        )

        let result = convert(configuration)

        XCTAssertEqual(result?.allowedEvents, [.viewCreated])
    }

    func testOnlyUnsupportedStringsConvertToEmptySet() {
        let configuration = LifecycleConfigurationObjC(
            allowedEvents: [
                "started",
                "paused",
                "destroyed"
            ]
        )

        let result = convert(configuration)

        XCTAssertEqual(result?.allowedEvents, [])
    }

    func testDuplicateStringsDeduplicateDuringConversion() {
        let configuration = LifecycleConfigurationObjC(
            allowedEvents: [
                LifecycleActionObjC.viewCreated as String,
                LifecycleActionObjC.viewCreated as String,
                LifecycleActionObjC.resumed as String
            ]
        )

        let result = convert(configuration)

        XCTAssertEqual(result?.allowedEvents, [.viewCreated, .resumed])
    }

    func testEmptyArrayConvertsToEmptySet() {
        let configuration = LifecycleConfigurationObjC(allowedEvents: [])

        let result = convert(configuration)

        XCTAssertEqual(result?.allowedEvents, [])
    }


    // MARK: - String constant parity

    func testStringConstantsMatchSwiftRawValues() {
        XCTAssertEqual(LifecycleActionObjC.viewCreated as String, LifecycleAction.viewCreated.rawValue)
        XCTAssertEqual(LifecycleActionObjC.resumed as String, LifecycleAction.resumed.rawValue)
        XCTAssertEqual(LifecycleActionObjC.stopped as String, LifecycleAction.stopped.rawValue)
    }
}
