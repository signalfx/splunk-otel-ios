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
import XCTest

final class NavigationControllerSwizzlingTests: XCTestCase {

    func testPushAndPopUpdatesScreenName() async {
        let rootIdentifier = ObjectIdentifier(NSString())
        let detailIdentifier = ObjectIdentifier(NSString())
        let navigationControllerIdentifier = ObjectIdentifier(NSString())

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
            ),
            makeTransitionEvent(
                type: .navigationControllerWillShow,
                navigationControllerIdentifier: navigationControllerIdentifier,
                controllerIdentifier: rootIdentifier,
                controllerTypeName: "RootViewController"
            ),
            makeTransitionEvent(
                type: .navigationControllerDidShow,
                navigationControllerIdentifier: navigationControllerIdentifier,
                controllerIdentifier: rootIdentifier,
                controllerTypeName: "RootViewController"
            )
        ])

        let navigation = Navigation(
            navigationEventStreamProvider: MockNavigationEventStreamProvider(stream: events)
        )
        navigation.preferences.enableAutomatedTracking = true

        navigation.startDetection()

        let didReturnToRoot = await waitUntil {
            navigation.currentScreenNameForTesting == "RootViewController"
        }
        XCTAssertTrue(didReturnToRoot)
    }

    func testInteractivePopCancellationRestoresCurrentScreenName() async {
        let rootIdentifier = ObjectIdentifier(NSString())
        let detailIdentifier = ObjectIdentifier(NSNumber(value: 1))
        let navigationControllerIdentifier = ObjectIdentifier(NSNumber(value: 2))
        let fixture = makeNavigationStreamFixture()

        defer {
            fixture.finish()
        }

        let navigation = fixture.navigation
        navigation.preferences.enableAutomatedTracking = true

        navigation.startDetection()

        fixture.showController(
            navigationControllerIdentifier: navigationControllerIdentifier,
            controllerIdentifier: detailIdentifier,
            controllerTypeName: "DetailViewController"
        )

        let didShowDetail = await waitUntil {
            navigation.currentScreenNameForTesting == "DetailViewController"
        }
        XCTAssertTrue(didShowDetail)

        fixture.sendTransition(
            type: .navigationControllerWillShow,
            navigationControllerIdentifier: navigationControllerIdentifier,
            controllerIdentifier: rootIdentifier,
            controllerTypeName: "RootViewController"
        )

        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(navigation.currentScreenNameForTesting, "DetailViewController")

        fixture.sendTransition(
            type: .navigationControllerDidShow,
            navigationControllerIdentifier: navigationControllerIdentifier,
            controllerIdentifier: detailIdentifier,
            controllerTypeName: "DetailViewController"
        )

        let didStayOnDetail = await waitUntil {
            navigation.currentScreenNameForTesting == "DetailViewController"
        }
        XCTAssertTrue(didStayOnDetail)
        let finalScreenName = navigation.currentScreenNameForTesting
        XCTAssertEqual(finalScreenName, "DetailViewController")

        let didCollect = await waitUntil {
            await fixture.collector.values == ["DetailViewController"]
        }
        XCTAssertTrue(didCollect)
        let collected = await fixture.collector.values
        XCTAssertEqual(collected, ["DetailViewController"])
    }

    func testAutoDetectedNavigationReplacesManualScreenName() async {
        let detailIdentifier = ObjectIdentifier(NSString())
        let navigationControllerIdentifier = ObjectIdentifier(NSNumber(value: 3))

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

        navigation.track(screen: "ManualScreen")
        XCTAssertEqual(navigation.currentScreenNameForTesting, "ManualScreen")

        navigation.startDetection()

        let didApplyAuto = await waitUntil {
            navigation.currentScreenNameForTesting == "DetailViewController"
        }
        XCTAssertTrue(didApplyAuto)
    }

    func testAutoDisabledManualScreenNameIsPreserved() async {
        let detailIdentifier = ObjectIdentifier(NSString())
        let navigationControllerIdentifier = ObjectIdentifier(NSNumber(value: 4))

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
        navigation.preferences.enableAutomatedTracking = false

        navigation.track(screen: "ManualScreen")
        XCTAssertEqual(navigation.currentScreenNameForTesting, "ManualScreen")

        navigation.startDetection()

        try? await Task.sleep(nanoseconds: 200_000_000)

        let finalScreenName = navigation.currentScreenNameForTesting
        XCTAssertEqual(finalScreenName, "ManualScreen")
    }

    func testNavigationControllerOwnsManagedControllerLifecycleEvents() async {
        let detailIdentifier = ObjectIdentifier(NSString())
        let navigationControllerIdentifier = ObjectIdentifier(NSNumber(value: 5))
        let fixture = makeNavigationStreamFixture()

        defer {
            fixture.finish()
        }

        let navigation = fixture.navigation
        navigation.preferences.enableAutomatedTracking = true

        navigation.startDetection()

        fixture.sendTransition(
            type: .navigationControllerWillShow,
            navigationControllerIdentifier: navigationControllerIdentifier,
            controllerIdentifier: detailIdentifier,
            controllerTypeName: "DetailViewController"
        )

        let didRegisterPendingTarget = await waitUntil {
            await navigation.model.pendingNavigationTarget(
                for: navigationControllerIdentifier
            ) == detailIdentifier
        }
        XCTAssertTrue(didRegisterPendingTarget)

        fixture.sendManagedLifecycleEvents(
            controllerIdentifier: detailIdentifier,
            controllerTypeName: "DetailViewController"
        )

        try? await Task.sleep(nanoseconds: 200_000_000)
        let screenNameBeforeDidShow = navigation.currentScreenNameForTesting
        XCTAssertEqual(screenNameBeforeDidShow, "unknown")

        fixture.sendTransition(
            type: .navigationControllerDidShow,
            navigationControllerIdentifier: navigationControllerIdentifier,
            controllerIdentifier: detailIdentifier,
            controllerTypeName: "DetailViewController"
        )

        let didFinalize = await waitUntil {
            navigation.currentScreenNameForTesting == "DetailViewController"
        }
        XCTAssertTrue(didFinalize)

        let didCollect = await waitUntil {
            await fixture.collector.values == ["DetailViewController"]
        }
        XCTAssertTrue(didCollect)
        let collected = await fixture.collector.values
        XCTAssertEqual(collected, ["DetailViewController"])
    }
}
