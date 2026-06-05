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
@_spi(SplunkTesting) import SplunkNavigation
import UIKit
import XCTest

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
            navigation.currentScreenNameForTesting == "DetailViewController"
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
            navigation.currentScreenNameForTesting == "Custom/DetailViewController"
        }
        XCTAssertTrue(didUpdate)
    }

    func testNavigationControllerProcessorRunsOncePerCommittedTransition() async {
        let processor = CountingProcessor()
        let fixture = makeNavigationStreamFixture(
            navigationEventProcessor: processor
        )

        defer {
            fixture.finish()
        }

        let navigation = fixture.navigation
        navigation.preferences.enableAutomatedTracking = true
        navigation.startDetection()

        let detailIdentifier = ObjectIdentifier(NSString())
        let navigationControllerIdentifier = ObjectIdentifier(NSNumber(value: 20))

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

        let didUpdate = await waitUntil {
            navigation.currentScreenNameForTesting == "DetailViewController"
        }
        XCTAssertTrue(didUpdate)
        XCTAssertEqual(processor.callCount, 1)
    }

    // MARK: - Manual tracking bypass

    func testManualTrackBypassesProcessor() {
        let fixture = makeNavigationStreamFixture(
            navigationEventProcessor: NameOverridingProcessor()
        )

        defer {
            fixture.finish()
        }

        let navigation = fixture.navigation
        navigation.preferences.enableAutomatedTracking = true

        navigation.startDetection()

        navigation.track(screen: "ManualScreen")

        XCTAssertEqual(navigation.currentScreenNameForTesting, "ManualScreen")
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

        XCTAssertEqual(navigation.currentScreenNameForTesting, "ManualScreen")

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
            navigation.currentScreenNameForTesting == "Auto/DetailViewController"
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
            navigation.currentScreenNameForTesting == "Nav/PresentedViewController"
        }
        XCTAssertTrue(didUpdate)
    }

    @MainActor
    func testPresentationProcessorRunsOncePerCommittedTransition() async {
        let provider = MockPresentationEventStreamProvider()
        let processor = CountingProcessor()
        let navigation = Navigation(
            navigationEventStreamProvider: provider,
            navigationEventProcessor: processor
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
            navigation.currentScreenNameForTesting == "PresentedViewController"
        }
        XCTAssertTrue(didUpdate)
        XCTAssertEqual(processor.callCount, 1)
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

        XCTAssertEqual(navigation.currentScreenNameForTesting, "InitialScreen")

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

        let currentScreenName = navigation.currentScreenNameForTesting
        XCTAssertEqual(currentScreenName, "InitialScreen")
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

        XCTAssertEqual(navigation.currentScreenNameForTesting, "InitialScreen")

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
        let currentScreenName = navigation.currentScreenNameForTesting
        XCTAssertEqual(currentScreenName, "InitialScreen")
    }
}
