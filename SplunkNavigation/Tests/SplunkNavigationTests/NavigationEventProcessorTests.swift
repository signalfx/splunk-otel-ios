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

internal import CiscoSwizzling
import Foundation
@_spi(SplunkTesting) import SplunkCommon
import UIKit
import XCTest

@testable import SplunkNavigation

final class NavigationEventProcessorTests: XCTestCase {

    // MARK: - Default processor

    func testDefaultProcessorPassesScreenNameThrough() async {
        let detailIdentifier = ObjectIdentifier(NSString())
        let navigationControllerIdentifier = ObjectIdentifier(NSNumber(value: 1))

        let events = makeEventStream([
            makeTransitionEvent(
                type: .navigationControllerWillShow,
                navigationControllerIdentifier: navigationControllerIdentifier,
                controllerIdentifier: detailIdentifier,
                controllerTypeName: "DetailViewController"
            ),
            makeTransitionEvent(
                type: .navigationControllerDidShow,
                navigationControllerIdentifier: navigationControllerIdentifier,
                controllerIdentifier: detailIdentifier,
                controllerTypeName: "DetailViewController"
            )
        ])

        let navigation = Navigation(
            navigationEventStreamProvider: MockNavigationEventStreamProvider(stream: events)
        )
        navigation.preferences.enableAutomatedTracking = true
        navigation.startDetection()

        let didUpdate = await waitUntil {
            await navigation.model.screenName == "DetailViewController"
        }
        XCTAssertTrue(didUpdate)
    }

    // MARK: - Custom processor

    func testCustomProcessorTransformsScreenName() async {
        let detailIdentifier = ObjectIdentifier(NSString())
        let navigationControllerIdentifier = ObjectIdentifier(NSNumber(value: 2))

        let events = makeEventStream([
            makeTransitionEvent(
                type: .navigationControllerWillShow,
                navigationControllerIdentifier: navigationControllerIdentifier,
                controllerIdentifier: detailIdentifier,
                controllerTypeName: "DetailViewController"
            ),
            makeTransitionEvent(
                type: .navigationControllerDidShow,
                navigationControllerIdentifier: navigationControllerIdentifier,
                controllerIdentifier: detailIdentifier,
                controllerTypeName: "DetailViewController"
            )
        ])

        let navigation = Navigation(
            navigationEventStreamProvider: MockNavigationEventStreamProvider(stream: events),
            navigationEventProcessor: PrefixingProcessor(prefix: "Custom")
        )
        navigation.preferences.enableAutomatedTracking = true
        navigation.startDetection()

        let didUpdate = await waitUntil {
            await navigation.model.screenName == "Custom/DetailViewController"
        }
        XCTAssertTrue(didUpdate)
    }

    // MARK: - Manual tracking bypass

    func testManualTrackBypassesProcessor() async {
        let fixture = makeNavigationStreamFixture(
            navigationEventProcessor: RejectingProcessor()
        )

        defer {
            fixture.finish()
        }

        let navigation = fixture.navigation
        navigation.preferences.enableAutomatedTracking = true

        navigation.startDetection()

        navigation.track(screen: "ManualScreen")

        let didUpdate = await waitUntil {
            await navigation.model.screenName == "ManualScreen"
        }
        XCTAssertTrue(didUpdate)
    }

    func testProcessorAppliesToAutomatedButNotManual() async {
        let fixture = makeNavigationStreamFixture(
            navigationEventProcessor: PrefixingProcessor(prefix: "Auto")
        )

        defer {
            fixture.finish()
        }

        let navigation = fixture.navigation
        navigation.preferences.enableAutomatedTracking = true

        navigation.startDetection()

        navigation.track(screen: "ManualScreen")

        let didSetManual = await waitUntil {
            await navigation.model.screenName == "ManualScreen"
        }
        XCTAssertTrue(didSetManual)

        let detailIdentifier = ObjectIdentifier(NSString())
        let navigationControllerIdentifier = ObjectIdentifier(NSNumber(value: 3))

        fixture.sendTransition(
            type: .navigationControllerWillShow,
            navigationControllerIdentifier: navigationControllerIdentifier,
            controllerIdentifier: detailIdentifier,
            controllerTypeName: "DetailViewController"
        )
        fixture.sendTransition(
            type: .navigationControllerDidShow,
            navigationControllerIdentifier: navigationControllerIdentifier,
            controllerIdentifier: detailIdentifier,
            controllerTypeName: "DetailViewController"
        )

        let didSetAuto = await waitUntil {
            await navigation.model.screenName == "Auto/DetailViewController"
        }
        XCTAssertTrue(didSetAuto)
    }

    // MARK: - Presentation controller processor

    @MainActor
    func testProcessorOnPresentationTransitions() async {
        let provider = MockPresentationEventStreamProvider()
        let navigation = Navigation(
            navigationEventStreamProvider: provider,
            navigationEventProcessor: PrefixingProcessor(prefix: "Nav")
        )
        navigation.preferences.enableAutomatedTracking = true
        navigation.startDetection()

        let presentingController = PresentingViewController()
        let presentedController = PresentedViewController()

        provider.emit(
            eventType: .presentationWillBegin,
            presented: presentedController,
            presenting: presentingController,
            completed: nil
        )
        provider.emit(
            eventType: .presentationDidEnd,
            presented: presentedController,
            presenting: presentingController,
            completed: true
        )

        let didUpdate = await waitUntil {
            await navigation.model.screenName == "Nav/PresentedViewController"
        }
        XCTAssertTrue(didUpdate)
    }

    @MainActor
    func testProcessorSuppressesPresentations() async {
        let provider = MockPresentationEventStreamProvider()
        let navigation = Navigation(
            navigationEventStreamProvider: provider,
            navigationEventProcessor: SuppressingProcessor()
        )
        navigation.preferences.enableAutomatedTracking = true
        navigation.startDetection()

        navigation.track(screen: "InitialScreen")

        let didSetInitial = await waitUntil {
            await navigation.model.screenName == "InitialScreen"
        }
        XCTAssertTrue(didSetInitial)

        let presentingController = PresentingViewController()
        let presentedController = PresentedViewController()

        provider.emit(
            eventType: .presentationWillBegin,
            presented: presentedController,
            presenting: presentingController,
            completed: nil
        )
        provider.emit(
            eventType: .presentationDidEnd,
            presented: presentedController,
            presenting: presentingController,
            completed: true
        )

        try? await Task.sleep(nanoseconds: 200_000_000)

        let currentScreenName = await navigation.model.screenName
        XCTAssertEqual(currentScreenName, "InitialScreen")
    }


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

    func testReservedSpanKeysCannotBeOverriddenByProcessor() async {
        // Use a processor that returns attributes containing all SDK-reserved keys.
        let fixture = makeNavigationStreamFixture(
            navigationEventProcessor: ReservedKeyOverrideProcessor()
        )

        defer {
            fixture.finish()
        }

        let navigation = fixture.navigation
        navigation.preferences.enableAutomatedTracking = true
        navigation.startDetection()

        // Set an initial screen via manual tracking so last.screen.name has a known value.
        navigation.track(screen: "HomeScreen")

        let didSetInitial = await waitUntil {
            await navigation.model.screenName == "HomeScreen"
        }
        XCTAssertTrue(didSetInitial)

        // Trigger an automated navigation event through the processor.
        let controllerIdentifier = ObjectIdentifier(NSString())
        let navigationControllerIdentifier = ObjectIdentifier(NSNumber(value: 99))

        fixture.sendTransition(
            type: .navigationControllerWillShow,
            navigationControllerIdentifier: navigationControllerIdentifier,
            controllerIdentifier: controllerIdentifier,
            controllerTypeName: "SettingsViewController"
        )
        fixture.sendTransition(
            type: .navigationControllerDidShow,
            navigationControllerIdentifier: navigationControllerIdentifier,
            controllerIdentifier: controllerIdentifier,
            controllerTypeName: "SettingsViewController"
        )

        // The processor returns name: "SettingsViewController" with attributes
        // attempting to set screen.name, last.screen.name, component, and
        // navigation.name to "hacker". Verify the SDK uses the processor's
        // `name` field for the screen name, not the "screen.name" attribute.
        let didUpdate = await waitUntil {
            await navigation.model.screenName == "SettingsViewController"
        }
        XCTAssertTrue(didUpdate)

        let currentScreenName = await navigation.model.screenName
        XCTAssertEqual(
            currentScreenName,
            "SettingsViewController",
            "Screen name must come from NavigationEvent.name, not from the 'screen.name' attribute"
        )
        XCTAssertNotEqual(
            currentScreenName,
            "hacker",
            "Processor attributes must not override the SDK-computed screen name"
        )

        // Verify the processor returns an event that carries the override attributes.
        // Navigation+Span.swift writes these user attributes BEFORE the SDK-reserved
        // keys (component, navigation.name, screen.name, last.screen.name) so that
        // clearAndSetAttribute for SDK keys always wins.
        let processedEvent = await navigation.processAutomatedNavigationEvent(
            "SettingsViewController",
            controllerIdentifier: controllerIdentifier
        )
        XCTAssertNotNil(processedEvent)
        XCTAssertEqual(processedEvent?.name, "SettingsViewController")
        XCTAssertNotNil(
            processedEvent?.attributes,
            "Processor should return attributes (including reserved key overrides)"
        )

        // Confirm the processor did return attributes that attempt to override reserved keys.
        // The span-level protection is structural: send(screenName:lastScreenName:start:attributes:)
        // in Navigation+Span.swift writes user attributes first, then overwrites with SDK values.
        let attrs = processedEvent?.attributes
        XCTAssertEqual(attrs?["screen.name"] as? String, "hacker")
        XCTAssertEqual(attrs?["component"] as? String, "hacker")
        XCTAssertEqual(attrs?["navigation.name"] as? String, "hacker")
        XCTAssertEqual(attrs?["last.screen.name"] as? String, "hacker")
    }


    // MARK: - Event suppression

    func testProcessorNilSuppressesNavigation() async {
        let fixture = makeNavigationStreamFixture(
            navigationEventProcessor: SuppressingProcessor()
        )

        defer {
            fixture.finish()
        }

        let navigation = fixture.navigation
        navigation.preferences.enableAutomatedTracking = true

        navigation.startDetection()

        // Set an initial screen name manually (bypasses processor)
        navigation.track(screen: "InitialScreen")

        let didSetInitial = await waitUntil {
            await navigation.model.screenName == "InitialScreen"
        }
        XCTAssertTrue(didSetInitial)

        // Send an automated navigation event; the suppressing processor returns nil
        let detailIdentifier = ObjectIdentifier(NSString())
        let navigationControllerIdentifier = ObjectIdentifier(NSNumber(value: 10))

        fixture.sendTransition(
            type: .navigationControllerWillShow,
            navigationControllerIdentifier: navigationControllerIdentifier,
            controllerIdentifier: detailIdentifier,
            controllerTypeName: "SuppressedViewController"
        )
        fixture.sendTransition(
            type: .navigationControllerDidShow,
            navigationControllerIdentifier: navigationControllerIdentifier,
            controllerIdentifier: detailIdentifier,
            controllerTypeName: "SuppressedViewController"
        )

        // Give the event loop time to process
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Screen name should remain unchanged because the event was suppressed
        let currentScreenName = await navigation.model.screenName
        XCTAssertEqual(currentScreenName, "InitialScreen")
    }
}


// MARK: - Test processors

private final class PrefixingProcessor: NavigationEventProcessor {
    let prefix: String

    init(prefix: String) {
        self.prefix = prefix
    }

    func onViewController(typeName: String, controllerIdentity _: String) -> NavigationEvent? {
        NavigationEvent(name: "\(prefix)/\(typeName)")
    }
}

private final class RejectingProcessor: NavigationEventProcessor {
    func onViewController(typeName _: String, controllerIdentity _: String) -> NavigationEvent? {
        NavigationEvent(name: "REJECTED")
    }
}

private final class SuppressingProcessor: NavigationEventProcessor {
    func onViewController(typeName _: String, controllerIdentity _: String) -> NavigationEvent? {
        nil
    }
}

private final class AllowThenSuppressProcessor: NavigationEventProcessor {
    private let lock = NSLock()
    private var callCount = 0

    func onViewController(typeName: String, controllerIdentity _: String) -> NavigationEvent? {
        lock.lock()
        defer { lock.unlock() }

        callCount += 1

        if callCount == 1 {
            return NavigationEvent(name: typeName)
        }

        return nil
    }
}

/// Returns the event with attributes that attempt to override all SDK-reserved span keys.
private final class ReservedKeyOverrideProcessor: NavigationEventProcessor {
    func onViewController(typeName: String, controllerIdentity _: String) -> NavigationEvent? {
        NavigationEvent(
            name: typeName,
            attributes: [
                "screen.name": "hacker",
                "last.screen.name": "hacker",
                "component": "hacker",
                "navigation.name": "hacker"
            ]
        )
    }
}
