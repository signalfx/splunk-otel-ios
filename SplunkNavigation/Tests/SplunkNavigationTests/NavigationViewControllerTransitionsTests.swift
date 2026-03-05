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

        XCTAssertTrue(await waitUntil { continuationBox.continuation != nil })

        continuationBox.continuation?
            .yield(
                event(type: .viewDidLoad, controllerIdentifier: controllerIdentifier)
            )
        XCTAssertTrue(
            await waitUntil {
                await navigation.model.navigation(for: controllerIdentifier)?.type == .show
            }
        )

        continuationBox.continuation?
            .yield(
                event(type: .viewDidDisappear, controllerIdentifier: controllerIdentifier)
            )
        XCTAssertTrue(
            await waitUntil {
                await navigation.model.navigation(for: controllerIdentifier) == nil
            }
        )

        continuationBox.continuation?.finish()
    }

    func testViewWillAndDidTransition_StartAndFinalizeTransition() async {
        let continuationBox = NavigationEventContinuationBox()
        let navigation = makeNavigation(continuationBox: continuationBox)
        let controllerIdentifier = ObjectIdentifier(NSString())

        navigation.preferences.enableAutomatedTracking = true
        navigation.startDetection()

        XCTAssertTrue(await waitUntil { continuationBox.continuation != nil })

        continuationBox.continuation?
            .yield(
                event(type: .viewWillTransition, controllerIdentifier: controllerIdentifier)
            )
        XCTAssertTrue(
            await waitUntil {
                await navigation.model.navigation(for: controllerIdentifier)?.type == .transition
            }
        )

        continuationBox.continuation?
            .yield(
                event(type: .viewDidTransition, controllerIdentifier: controllerIdentifier)
            )
        XCTAssertTrue(
            await waitUntil {
                await navigation.model.navigation(for: controllerIdentifier) == nil
            }
        )

        continuationBox.continuation?.finish()
    }

    func testTransitionStartDedupesOverlappingWillSignals() async {
        let continuationBox = NavigationEventContinuationBox()
        let navigation = makeNavigation(continuationBox: continuationBox)
        let controllerIdentifier = ObjectIdentifier(NSString())

        navigation.preferences.enableAutomatedTracking = true
        navigation.startDetection()

        XCTAssertTrue(await waitUntil { continuationBox.continuation != nil })

        continuationBox.continuation?
            .yield(
                event(type: .willTransitionToTraitCollection, controllerIdentifier: controllerIdentifier)
            )
        XCTAssertTrue(
            await waitUntil {
                await navigation.model.navigation(for: controllerIdentifier)?.type == .transition
            }
        )
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

        XCTAssertEqual(firstStart, secondStart)

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
    controllerIdentifier: ObjectIdentifier
) -> AutomatedNavigationEvent {
    AutomatedNavigationEvent(
        timestamp: Date(),
        type: type,
        controllerTypeName: "MockViewController",
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
