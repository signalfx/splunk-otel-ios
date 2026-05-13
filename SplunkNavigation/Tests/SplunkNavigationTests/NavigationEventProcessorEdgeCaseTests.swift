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
@_spi(SplunkTesting) import SplunkCommon
import XCTest

@testable import SplunkNavigation

/// Tests for edge-case processor behaviors: mid-transition suppression cleanup
/// and SDK-reserved span key protection.
final class NavigationEventProcessorEdgeCaseTests: XCTestCase {

    // MARK: - Mid-transition suppression cleanup

    func testDidShowSuppressionCleansUpNavigationPair() async {
        let fixture = makeNavigationStreamFixture(
            navigationEventProcessor: AllowThenSuppressProcessor()
        )

        defer {
            fixture.finish()
        }

        let navigation = fixture.navigation
        navigation.preferences.enableAutomatedTracking = true
        navigation.startDetection()

        let controllerIdentifier = ObjectIdentifier(NSString())
        let navigationControllerIdentifier = ObjectIdentifier(NSNumber(value: 50))

        fixture.sendTransition(
            type: .navigationControllerWillShow,
            navigationControllerIdentifier: navigationControllerIdentifier,
            controllerIdentifier: controllerIdentifier,
            controllerTypeName: "TransientViewController"
        )

        // Wait for willShow to be processed and NavigationPair to be stored
        try? await Task.sleep(nanoseconds: 200_000_000)

        fixture.sendTransition(
            type: .navigationControllerDidShow,
            navigationControllerIdentifier: navigationControllerIdentifier,
            controllerIdentifier: controllerIdentifier,
            controllerTypeName: "TransientViewController"
        )

        // Wait for didShow suppression to clean up
        try? await Task.sleep(nanoseconds: 200_000_000)

        let pair = await navigation.model.navigation(for: controllerIdentifier)
        XCTAssertNil(pair, "NavigationPair should be removed when processor suppresses at didShow")
    }


    // MARK: - Reserved span key protection

    func testProcessorReservedKeyOverrideDoesNotLeakIntoModel() async throws {
        let fixture = makeNavigationStreamFixture(
            navigationEventProcessor: ReservedKeyOverrideProcessor()
        )
        defer { fixture.finish() }

        let navigation = fixture.navigation
        navigation.preferences.enableAutomatedTracking = true
        navigation.startDetection()

        navigation.track(screen: "HomeScreen")
        XCTAssertEqual(navigation.currentScreenNameForTesting, "HomeScreen")

        let controllerIdentifier = ObjectIdentifier(NSString())
        let navControllerIdentifier = ObjectIdentifier(NSNumber(value: 99))

        fixture.sendTransition(
            type: .navigationControllerWillShow,
            navigationControllerIdentifier: navControllerIdentifier,
            controllerIdentifier: controllerIdentifier,
            controllerTypeName: "SettingsViewController"
        )
        fixture.sendTransition(
            type: .navigationControllerDidShow,
            navigationControllerIdentifier: navControllerIdentifier,
            controllerIdentifier: controllerIdentifier,
            controllerTypeName: "SettingsViewController"
        )

        // Verify the SDK uses the processor's `name` field for the screen name,
        // not the "screen.name" attribute the processor also returned.
        let didUpdate = await waitUntil {
            navigation.currentScreenNameForTesting == "SettingsViewController"
        }
        XCTAssertTrue(didUpdate)

        let currentScreenName = navigation.currentScreenNameForTesting
        XCTAssertEqual(
            currentScreenName,
            "SettingsViewController",
            "Screen name must come from NavigationEvent.name, not from the 'screen.name' attribute"
        )

        // Confirm the processor did return attributes that attempt to override reserved keys.
        // Navigation+Span.swift writes user attributes first, then overwrites with SDK values.
        let processedEvent = await navigation.processAutomatedNavigationEvent(
            "SettingsViewController",
            controllerIdentifier: controllerIdentifier
        )
        let attrs = try XCTUnwrap(processedEvent?.attributes)
        XCTAssertEqual(attrs["screen.name"] as? String, "hacker")
        XCTAssertEqual(attrs["component"] as? String, "hacker")
        XCTAssertEqual(attrs["navigation.name"] as? String, "hacker")
        XCTAssertEqual(attrs["last.screen.name"] as? String, "hacker")
    }
}
