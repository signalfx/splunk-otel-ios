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

final class NavigationEventSourcesTests: XCTestCase {

    // MARK: - Seams

    func testModernNavigationStream_UsesInjectedProvider() async throws {
        let expectedName = "MockViewController"
        let expectedEvent = AutomatedNavigationEvent(
            timestamp: Date(),
            type: .viewDidAppear,
            controllerTypeName: expectedName,
            controllerIdentifier: ObjectIdentifier(NSString())
        )

        let navigation = Navigation(
            navigationEventStreamProvider: MockNavigationEventStreamProvider(
                stream: makeStream([expectedEvent])
            )
        )

        let stream = try await navigation.modernNavigationStream()
        var iterator = stream.makeAsyncIterator()
        let firstEvent = await iterator.next()

        XCTAssertEqual(firstEvent?.controllerTypeName, expectedName)
    }

    func testDefaultProviders_RemainProductionImplementations() {
        let navigation = Navigation()

        XCTAssertTrue(type(of: navigation.navigationEventStreamProvider) == DefaultNavigationEventStreamProvider.self)
    }

    // MARK: - Filtering scaffold

    func testShouldIgnore_ReturnsTrueForKnownInternalControllers() {
        let navigation = Navigation()

        XCTAssertTrue(navigation.shouldIgnore(controllerTypeName: "UINavigationController"))
        XCTAssertTrue(navigation.shouldIgnore(controllerTypeName: "UITabBarController"))
    }

    func testShouldIgnore_ReturnsFalseForRegularControllerName() {
        let navigation = Navigation()

        XCTAssertFalse(navigation.shouldIgnore(controllerTypeName: "ProductDetailsViewController"))
    }

    func testIgnoredControllerEvent_DoesNotUpdateScreenName() async {
        let (stream, continuation) = AsyncStream.makeStream(of: (any NavigationActionEvent).self)
        defer { continuation.finish() }

        let navigation = Navigation(
            navigationEventStreamProvider: MockNavigationEventStreamProvider(stream: stream)
        )
        navigation.preferences.enableAutomatedTracking = true

        navigation.startDetection()

        continuation.yield(
            AutomatedNavigationEvent(
                timestamp: Date(),
                type: .viewDidLoad,
                controllerTypeName: "UINavigationController",
                controllerIdentifier: ObjectIdentifier(NSString())
            )
        )

        try? await Task.sleep(nanoseconds: 50_000_000)

        let currentScreenName = await navigation.model.screenName
        XCTAssertEqual(currentScreenName, "unknown")
    }

    func testManualUpdateOverridesExistingAutomatedScreenName() async {
        let (stream, continuation) = AsyncStream.makeStream(of: (any NavigationActionEvent).self)
        defer { continuation.finish() }

        let navigation = Navigation(
            navigationEventStreamProvider: MockNavigationEventStreamProvider(stream: stream)
        )
        navigation.preferences.enableAutomatedTracking = true

        navigation.startDetection()

        continuation.yield(
            AutomatedNavigationEvent(
                timestamp: Date(),
                type: .viewDidLoad,
                controllerTypeName: "AutoViewController",
                controllerIdentifier: ObjectIdentifier(NSString())
            )
        )

        let didApplyAutomatedScreen = await waitUntil {
            await navigation.model.screenName == "AutoViewController"
        }
        XCTAssertTrue(didApplyAutomatedScreen)

        navigation.track(screen: "ManualScreen")

        let didApplyManualScreen = await waitUntil {
            await navigation.model.screenName == "ManualScreen"
        }
        XCTAssertTrue(didApplyManualScreen)
    }

    func testAutomaticUpdateOverridesManualScreenNameWhenAutomatedTrackingEnabled() async {
        let (stream, continuation) = AsyncStream.makeStream(of: (any NavigationActionEvent).self)
        defer { continuation.finish() }

        let navigation = Navigation(
            navigationEventStreamProvider: MockNavigationEventStreamProvider(stream: stream)
        )
        navigation.preferences.enableAutomatedTracking = true

        navigation.track(screen: "ManualScreen")

        let didApplyManualScreen = await waitUntil {
            await navigation.model.screenName == "ManualScreen"
        }
        XCTAssertTrue(didApplyManualScreen)

        navigation.startDetection()

        continuation.yield(
            AutomatedNavigationEvent(
                timestamp: Date(),
                type: .viewDidLoad,
                controllerTypeName: "AutoViewController",
                controllerIdentifier: ObjectIdentifier(NSString())
            )
        )

        let didApplyAutomatedScreen = await waitUntil {
            await navigation.model.screenName == "AutoViewController"
        }
        XCTAssertTrue(didApplyAutomatedScreen)
    }

    func testAutomaticUpdateDoesNotOverrideManualScreenNameWhenAutomatedTrackingDisabled() async {
        let (stream, continuation) = AsyncStream.makeStream(of: (any NavigationActionEvent).self)
        defer { continuation.finish() }

        let navigation = Navigation(
            navigationEventStreamProvider: MockNavigationEventStreamProvider(stream: stream)
        )

        navigation.track(screen: "ManualScreen")

        let didApplyManualScreen = await waitUntil {
            await navigation.model.screenName == "ManualScreen"
        }
        XCTAssertTrue(didApplyManualScreen)

        navigation.startDetection()

        continuation.yield(
            AutomatedNavigationEvent(
                timestamp: Date(),
                type: .viewDidLoad,
                controllerTypeName: "AutoViewController",
                controllerIdentifier: ObjectIdentifier(NSString())
            )
        )

        try? await Task.sleep(nanoseconds: 50_000_000)

        let currentScreenName = await navigation.model.screenName
        XCTAssertEqual(currentScreenName, "ManualScreen")
    }

    func testStreamInitializationFailure_RetriesAndRecovers() async {
        let (stream, continuation) = AsyncStream.makeStream(of: (any NavigationActionEvent).self)
        defer { continuation.finish() }

        let navigation = Navigation(
            navigationEventStreamProvider: RetryNavigationEventStreamProvider(stream: stream)
        )
        navigation.preferences.enableAutomatedTracking = true

        navigation.startDetection()

        continuation.yield(
            AutomatedNavigationEvent(
                timestamp: Date(),
                type: .viewDidLoad,
                controllerTypeName: "RecoveredViewController",
                controllerIdentifier: ObjectIdentifier(NSString())
            )
        )

        let didRecover = await waitUntil(timeout: 2.0) {
            await navigation.model.screenName == "RecoveredViewController"
        }
        XCTAssertTrue(didRecover)
    }
}

private struct MockNavigationEventStreamProvider: NavigationEventStreamProviding {
    let stream: AsyncStream<any NavigationActionEvent>

    func navigationStream() async throws -> AsyncStream<any NavigationActionEvent> {
        await Task.yield()
        return stream
    }
}

private struct RetryNavigationEventStreamProvider: NavigationEventStreamProviding {
    let state: RetryNavigationEventStreamProviderState

    init(stream: AsyncStream<any NavigationActionEvent>) {
        state = RetryNavigationEventStreamProviderState(stream: stream)
    }

    func navigationStream() async throws -> AsyncStream<any NavigationActionEvent> {
        try await state.navigationStream()
    }
}

private actor RetryNavigationEventStreamProviderState {
    private var shouldThrow = true
    private let stream: AsyncStream<any NavigationActionEvent>

    init(stream: AsyncStream<any NavigationActionEvent>) {
        self.stream = stream
    }

    func navigationStream() throws -> AsyncStream<any NavigationActionEvent> {
        if shouldThrow {
            shouldThrow = false
            throw MockNavigationStreamError.initializationFailed
        }

        return stream
    }
}

private enum MockNavigationStreamError: Error {
    case initializationFailed
}

private func makeStream<T>(_ values: [T]) -> AsyncStream<T> {
    AsyncStream { continuation in
        for value in values {
            continuation.yield(value)
        }
        continuation.finish()
    }
}
