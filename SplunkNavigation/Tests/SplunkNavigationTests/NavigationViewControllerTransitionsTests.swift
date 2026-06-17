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
import XCTest
@testable import SplunkNavigation // swiftlint:disable:this sorted_imports

final class NavigationViewControllerTransitionsTests: XCTestCase {

    // MARK: - Transition processing

    func testViewDidLoadStoresPendingShowWithoutUpdatingScreen() async {
        let (navigation, continuation) = makeNavigation()
        let controllerIdentifier = ObjectIdentifier(NSString())

        navigation.preferences.enableAutomatedTracking = true
        navigation.startDetection()

        continuation.yield(
            event(type: .viewDidLoad, controllerIdentifier: controllerIdentifier)
        )
        let showStarted = await waitUntil {
            await navigation.model.navigation(for: controllerIdentifier)?.type == .show
        }
        XCTAssertTrue(showStarted)

        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(navigation.currentScreenNameForTesting, "unknown")

        continuation.finish()
    }

    func testViewDidAppearCommitsPendingShowAndUpdatesScreen() async {
        let (navigation, continuation) = makeNavigation()
        var screenNameIterator = navigation.screenNameStream.makeAsyncIterator()
        let controllerIdentifier = ObjectIdentifier(NSString())

        navigation.preferences.enableAutomatedTracking = true
        navigation.startDetection()

        continuation.yield(
            event(type: .viewDidLoad, controllerIdentifier: controllerIdentifier)
        )
        let showStarted = await waitUntil {
            await navigation.model.navigation(for: controllerIdentifier)?.type == .show
        }
        XCTAssertTrue(showStarted)

        continuation.yield(
            event(
                type: .viewDidAppear,
                controllerIdentifier: controllerIdentifier,
                controllerTypeName: "AppearedViewController"
            )
        )

        let didUpdateActiveScreen = await waitUntil {
            navigation.currentScreenNameForTesting == "AppearedViewController"
        }
        XCTAssertTrue(didUpdateActiveScreen)

        let emittedScreenName = await screenNameIterator.next()
        XCTAssertEqual(emittedScreenName, "AppearedViewController")

        let showFinalized = await waitUntil {
            await navigation.model.navigation(for: controllerIdentifier) == nil
        }
        XCTAssertTrue(showFinalized)

        continuation.finish()
    }

    func testViewDidDisappearCleansUpUncommittedShow() async {
        let (navigation, continuation) = makeNavigation()
        let controllerIdentifier = ObjectIdentifier(NSString())

        navigation.preferences.enableAutomatedTracking = true
        navigation.startDetection()

        continuation.yield(
            event(type: .viewDidLoad, controllerIdentifier: controllerIdentifier)
        )
        let showStarted = await waitUntil {
            await navigation.model.navigation(for: controllerIdentifier)?.type == .show
        }
        XCTAssertTrue(showStarted)

        continuation.yield(
            event(type: .viewDidDisappear, controllerIdentifier: controllerIdentifier)
        )
        let showCleanedUp = await waitUntil {
            await navigation.model.navigation(for: controllerIdentifier) == nil
        }
        XCTAssertTrue(showCleanedUp)
        XCTAssertEqual(navigation.currentScreenNameForTesting, "unknown")

        continuation.finish()
    }

    func testTraitAndRotationEventsDoNotStartNavigationOrUpdateScreen() async {
        let (navigation, continuation) = makeNavigation()
        let controllerIdentifier = ObjectIdentifier(NSString())

        navigation.preferences.enableAutomatedTracking = true
        navigation.track(screen: "ManualScreen")
        navigation.startDetection()

        continuation.yield(event(type: .willTransitionToTraitCollection, controllerIdentifier: controllerIdentifier))
        continuation.yield(event(type: .didTransitionToTraitCollection, controllerIdentifier: controllerIdentifier))
        continuation.yield(event(type: .viewWillTransition, controllerIdentifier: controllerIdentifier))
        continuation.yield(event(type: .viewDidTransition, controllerIdentifier: controllerIdentifier))
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(navigation.currentScreenNameForTesting, "ManualScreen")
        let pendingNavigation = await navigation.model.navigation(for: controllerIdentifier)
        XCTAssertNil(pendingNavigation)

        continuation.finish()
    }

    func testTraitAndRotationEventsDoNotOverrideManualWhenEnabled() async {
        let (navigation, continuation) = makeNavigation()
        let controllerIdentifier = ObjectIdentifier(NSString())

        navigation.preferences.enableAutomatedTracking = true
        navigation.track(screen: "ManualScreen")

        XCTAssertEqual(navigation.currentScreenNameForTesting, "ManualScreen")

        navigation.startDetection()

        continuation.yield(
            event(
                type: .viewWillTransition,
                controllerIdentifier: controllerIdentifier,
                controllerTypeName: "TransitionViewController"
            )
        )

        try? await Task.sleep(nanoseconds: 200_000_000)

        let currentScreenName = navigation.currentScreenNameForTesting
        XCTAssertEqual(currentScreenName, "ManualScreen")

        continuation.finish()
    }

    func testTransitionUpdateDoesNotOverrideManualWhenDisabled() async {
        let (navigation, continuation) = makeNavigation()
        let controllerIdentifier = ObjectIdentifier(NSString())

        navigation.track(screen: "ManualScreen")

        XCTAssertEqual(navigation.currentScreenNameForTesting, "ManualScreen")

        navigation.startDetection()

        continuation.yield(
            event(
                type: .viewWillTransition,
                controllerIdentifier: controllerIdentifier,
                controllerTypeName: "TransitionViewController"
            )
        )

        try? await Task.sleep(nanoseconds: 200_000_000)

        let currentScreenName = navigation.currentScreenNameForTesting
        XCTAssertEqual(currentScreenName, "ManualScreen")

        continuation.finish()
    }
}

private func makeNavigation() -> (Navigation, AsyncStream<any NavigationActionEvent>.Continuation) {
    let (stream, continuation) = AsyncStream.makeStream(
        of: (any NavigationActionEvent).self
    )

    let navigation = Navigation(
        navigationEventStreamProvider: MockNavigationEventStreamProvider(stream: stream)
    )

    return (navigation, continuation)
}

private func event(
    type: NavigationActionEventType,
    controllerIdentifier: ObjectIdentifier,
    controllerTypeName: String = "MockViewController"
) -> AutomatedNavigationEvent {
    AutomatedNavigationEvent(
        timestamp: Date(),
        type: type,
        controllerTypeName: controllerTypeName,
        controllerIdentifier: controllerIdentifier
    )
}
