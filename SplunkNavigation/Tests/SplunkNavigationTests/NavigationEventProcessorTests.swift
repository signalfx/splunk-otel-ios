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
    func testProcessorApplesToPresentationTransitions() async {
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
    func testProcessorSuppressesPresentationTransition() async {
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


    // MARK: - Event suppression

    func testProcessorReturningNilSuppressesNavigation() async {
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

    func onViewController(typeName: String, controllerIdentity: String) -> NavigationEvent? {
        NavigationEvent(
            name: "\(prefix)/\(typeName)",
            controllerIdentity: controllerIdentity
        )
    }
}

private final class RejectingProcessor: NavigationEventProcessor {
    func onViewController(typeName: String, controllerIdentity: String) -> NavigationEvent? {
        _ = typeName
        return NavigationEvent(
            name: "REJECTED",
            controllerIdentity: controllerIdentity
        )
    }
}

private final class SuppressingProcessor: NavigationEventProcessor {
    func onViewController(typeName: String, controllerIdentity: String) -> NavigationEvent? {
        _ = typeName
        _ = controllerIdentity
        return nil
    }
}
