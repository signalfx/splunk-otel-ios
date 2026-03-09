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

    func testAutomatedEventOverridesManualScreenName() async {
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

        let isManualScreenName = await navigation.model.isManualScreenName
        XCTAssertTrue(isManualScreenName)

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
}

private struct MockNavigationEventStreamProvider: NavigationEventStreamProviding {
    let stream: AsyncStream<any NavigationActionEvent>

    func navigationStream() async throws -> AsyncStream<any NavigationActionEvent> {
        await Task.yield()
        return stream
    }
}

private func makeStream<T>(_ values: [T]) -> AsyncStream<T> {
    AsyncStream { continuation in
        for value in values {
            continuation.yield(value)
        }
        continuation.finish()
    }
}

private func waitUntil(
    timeout: TimeInterval = 1.0,
    pollIntervalNanoseconds: UInt64 = 10_000_000,
    _ condition: @escaping @Sendable () async -> Bool
) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)

    while Date() < deadline {
        if await condition() {
            return true
        }

        try? await Task.sleep(nanoseconds: pollIntervalNanoseconds)
    }

    return await condition()
}
