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
import XCTest

@testable import SplunkNavigation

final class NavigationViewControllerTransitionsTests: XCTestCase {

    // MARK: - Transition processing

    func testViewDidDisappear_FinalizesPendingShowNavigation() async {
        let continuationBox = NavigationEventContinuationBox()
        let navigation = makeNavigation(continuationBox: continuationBox)
        let controllerIdentifier = ObjectIdentifier(NSString())

        navigation.preferences.enableAutomatedTracking = true
        navigation.startDetection()

        let streamReady = await waitUntil { continuationBox.continuation != nil }
        XCTAssertTrue(streamReady)

        continuationBox.continuation?
            .yield(
                event(type: .viewDidLoad, controllerIdentifier: controllerIdentifier)
            )
        let showStarted = await waitUntil {
            await navigation.model.navigation(for: controllerIdentifier)?.type == .show
        }
        XCTAssertTrue(showStarted)

        continuationBox.continuation?
            .yield(
                event(type: .viewDidDisappear, controllerIdentifier: controllerIdentifier)
            )
        let showFinalized = await waitUntil {
            await navigation.model.navigation(for: controllerIdentifier) == nil
        }
        XCTAssertTrue(showFinalized)

        continuationBox.continuation?.finish()
    }

    func testViewWillAndDidTransition_StartAndFinalizeTransition() async {
        let continuationBox = NavigationEventContinuationBox()
        let navigation = makeNavigation(continuationBox: continuationBox)
        let controllerIdentifier = ObjectIdentifier(NSString())

        navigation.preferences.enableAutomatedTracking = true
        navigation.startDetection()

        let streamReady = await waitUntil { continuationBox.continuation != nil }
        XCTAssertTrue(streamReady)

        continuationBox.continuation?
            .yield(
                event(type: .viewWillTransition, controllerIdentifier: controllerIdentifier)
            )
        let transitionStarted = await waitUntil {
            await navigation.model.navigation(for: controllerIdentifier)?.type == .transition
        }
        XCTAssertTrue(transitionStarted)

        continuationBox.continuation?
            .yield(
                event(type: .viewDidTransition, controllerIdentifier: controllerIdentifier)
            )
        let transitionFinalized = await waitUntil {
            await navigation.model.navigation(for: controllerIdentifier) == nil
        }
        XCTAssertTrue(transitionFinalized)

        continuationBox.continuation?.finish()
    }

    func testViewWillTransition_UpdatesActiveScreenAndStream() async {
        let continuationBox = NavigationEventContinuationBox()
        let navigation = makeNavigation(continuationBox: continuationBox)
        var screenNameIterator = navigation.screenNameStream.makeAsyncIterator()
        let controllerIdentifier = ObjectIdentifier(NSString())

        navigation.preferences.enableAutomatedTracking = true
        navigation.startDetection()

        let streamReady = await waitUntil { continuationBox.continuation != nil }
        XCTAssertTrue(streamReady)

        continuationBox.continuation?
            .yield(
                event(
                    type: .viewWillTransition,
                    controllerIdentifier: controllerIdentifier,
                    controllerTypeName: "TransitionViewController"
                )
            )

        let didUpdateActiveScreen = await waitUntil {
            await navigation.model.screenName == "TransitionViewController"
        }
        XCTAssertTrue(didUpdateActiveScreen)

        let emittedScreenName = await screenNameIterator.next()
        XCTAssertEqual(emittedScreenName, "TransitionViewController")

        continuationBox.continuation?.finish()
    }

    func testTransitionStartReplacesOverlappingWillSignals() async {
        let continuationBox = NavigationEventContinuationBox()
        let navigation = makeNavigation(continuationBox: continuationBox)
        let controllerIdentifier = ObjectIdentifier(NSString())

        navigation.preferences.enableAutomatedTracking = true
        navigation.startDetection()

        let streamReady = await waitUntil { continuationBox.continuation != nil }
        XCTAssertTrue(streamReady)

        continuationBox.continuation?
            .yield(
                event(type: .willTransitionToTraitCollection, controllerIdentifier: controllerIdentifier)
            )
        let initialTransitionStarted = await waitUntil {
            await navigation.model.navigation(for: controllerIdentifier)?.type == .transition
        }
        XCTAssertTrue(initialTransitionStarted)
        guard let firstStart = await navigation.model.navigation(for: controllerIdentifier)?.start else {
            XCTFail("Expected first transition start to be stored.")
            return
        }

        continuationBox.continuation?
            .yield(
                event(type: .viewWillTransition, controllerIdentifier: controllerIdentifier)
            )
        try? await Task.sleep(nanoseconds: 50_000_000)

        guard let secondStart = await navigation.model.navigation(for: controllerIdentifier)?.start else {
            XCTFail("Expected transition to remain in-flight.")
            return
        }

        XCTAssertNotEqual(firstStart, secondStart)
        XCTAssertGreaterThanOrEqual(secondStart, firstStart)

        continuationBox.continuation?.finish()
    }

    func testTransitionUpdateOverridesManualScreenNameWhenAutomatedTrackingEnabled() async {
        let continuationBox = NavigationEventContinuationBox()
        let navigation = makeNavigation(continuationBox: continuationBox)
        let controllerIdentifier = ObjectIdentifier(NSString())

        navigation.preferences.enableAutomatedTracking = true
        navigation.track(screen: "ManualScreen")

        let didApplyManualScreen = await waitUntil {
            await navigation.model.screenName == "ManualScreen"
        }
        XCTAssertTrue(didApplyManualScreen)

        navigation.startDetection()

        let streamReady = await waitUntil { continuationBox.continuation != nil }
        XCTAssertTrue(streamReady)

        continuationBox.continuation?
            .yield(
                event(
                    type: .viewWillTransition,
                    controllerIdentifier: controllerIdentifier,
                    controllerTypeName: "TransitionViewController"
                )
            )

        let didApplyTransitionScreen = await waitUntil {
            await navigation.model.screenName == "TransitionViewController"
        }
        XCTAssertTrue(didApplyTransitionScreen)

        continuationBox.continuation?.finish()
    }

    func testTransitionUpdateDoesNotOverrideManualScreenNameWhenAutomatedTrackingDisabled() async {
        let continuationBox = NavigationEventContinuationBox()
        let navigation = makeNavigation(continuationBox: continuationBox)
        let controllerIdentifier = ObjectIdentifier(NSString())

        navigation.track(screen: "ManualScreen")

        let didApplyManualScreen = await waitUntil {
            await navigation.model.screenName == "ManualScreen"
        }
        XCTAssertTrue(didApplyManualScreen)

        navigation.startDetection()

        let streamReady = await waitUntil { continuationBox.continuation != nil }
        XCTAssertTrue(streamReady)

        continuationBox.continuation?
            .yield(
                event(
                    type: .viewWillTransition,
                    controllerIdentifier: controllerIdentifier,
                    controllerTypeName: "TransitionViewController"
                )
            )

        try? await Task.sleep(nanoseconds: 50_000_000)

        let currentScreenName = await navigation.model.screenName
        XCTAssertEqual(currentScreenName, "ManualScreen")

        continuationBox.continuation?.finish()
    }
}

private struct MockNavigationEventStreamProvider: NavigationEventStreamProviding {
    let stream: AsyncStream<any NavigationActionEvent>

    func navigationStream() async throws -> AsyncStream<any NavigationActionEvent> {
        await Task.yield()
        return stream
    }
}

private final class NavigationEventContinuationBox {
    var continuation: AsyncStream<any NavigationActionEvent>.Continuation?
}

private func makeNavigation(
    continuationBox: NavigationEventContinuationBox
) -> Navigation {
    let stream = AsyncStream<any NavigationActionEvent> { continuation in
        continuationBox.continuation = continuation
    }

    return Navigation(
        navigationEventStreamProvider: MockNavigationEventStreamProvider(stream: stream)
    )
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

private func waitUntil(
    timeout: TimeInterval = 1.0,
    pollNanoseconds: UInt64 = 10_000_000,
    condition: @escaping () async -> Bool
) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)

    while Date() < deadline {
        if await condition() {
            return true
        }

        try? await Task.sleep(nanoseconds: pollNanoseconds)
    }

    return await condition()
}
