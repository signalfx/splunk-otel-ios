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
import SplunkCommon
import XCTest

@testable import SplunkNavigation

final class NavigationSwizzleNavControllerTests: XCTestCase {

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
            await navigation.model.screenName == "RootViewController"
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

        showController(
            fixture: fixture,
            navigationControllerIdentifier: navigationControllerIdentifier,
            controllerIdentifier: detailIdentifier,
            controllerTypeName: "DetailViewController"
        )

        let didShowDetail = await waitUntil {
            await navigation.model.screenName == "DetailViewController"
        }
        XCTAssertTrue(didShowDetail)

        sendTransition(
            type: .navigationControllerWillShow,
            fixture: fixture,
            navigationControllerIdentifier: navigationControllerIdentifier,
            controllerIdentifier: rootIdentifier,
            controllerTypeName: "RootViewController"
        )

        let didApplyAttemptedPop = await waitUntil {
            await navigation.model.screenName == "RootViewController"
        }
        XCTAssertTrue(didApplyAttemptedPop)

        sendTransition(
            type: .navigationControllerDidShow,
            fixture: fixture,
            navigationControllerIdentifier: navigationControllerIdentifier,
            controllerIdentifier: detailIdentifier,
            controllerTypeName: "DetailViewController"
        )

        let didStayOnDetail = await waitUntil {
            await navigation.model.screenName == "DetailViewController"
        }
        XCTAssertTrue(didStayOnDetail)
        let finalScreenName = await navigation.model.screenName
        XCTAssertEqual(finalScreenName, "DetailViewController")
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
        let didApplyManual = await waitUntil {
            await navigation.model.screenName == "ManualScreen"
        }
        XCTAssertTrue(didApplyManual)

        navigation.startDetection()

        let didApplyAuto = await waitUntil {
            await navigation.model.screenName == "DetailViewController"
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
        let didApplyManual = await waitUntil {
            await navigation.model.screenName == "ManualScreen"
        }
        XCTAssertTrue(didApplyManual)

        navigation.startDetection()

        try? await Task.sleep(nanoseconds: 200_000_000)

        let finalScreenName = await navigation.model.screenName
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
        sendTransition(
            type: .navigationControllerWillShow,
            fixture: fixture,
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

        sendManagedLifecycleEvents(
            fixture: fixture,
            controllerIdentifier: detailIdentifier,
            controllerTypeName: "DetailViewController"
        )

        try? await Task.sleep(nanoseconds: 200_000_000)
        let screenNameBeforeDidShow = await navigation.model.screenName
        XCTAssertEqual(screenNameBeforeDidShow, "DetailViewController")

        sendTransition(
            type: .navigationControllerDidShow,
            fixture: fixture,
            navigationControllerIdentifier: navigationControllerIdentifier,
            controllerIdentifier: detailIdentifier,
            controllerTypeName: "DetailViewController"
        )

        let didFinalize = await waitUntil {
            await navigation.model.screenName == "DetailViewController"
        }
        XCTAssertTrue(didFinalize)

        let collected = await fixture.collector.values
        XCTAssertEqual(collected, ["DetailViewController"])
    }
}
