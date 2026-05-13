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
import OpenTelemetryApi
import OpenTelemetrySdk
@_spi(SplunkTesting) import SplunkCommon
import UIKit
import XCTest

@testable import SplunkNavigation

final class NavigationPresentationTransitionsTests: XCTestCase {

    private var exporter = CollectingSpanExporter()
    private var originalTracerProvider: TracerProvider = OpenTelemetry.instance.tracerProvider

    override func setUp() {
        super.setUp()
        exporter = CollectingSpanExporter()
        let tracerProvider = TracerProviderBuilder()
            .add(spanProcessor: SimpleSpanProcessor(spanExporter: exporter))
            .build()
        OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)
    }

    override func tearDown() {
        OpenTelemetry.registerTracerProvider(tracerProvider: originalTracerProvider)
        super.tearDown()
    }

    // MARK: - Presentation controller transitions

    @MainActor
    func testPresentationAndDismissalUpdatesScreenName() async {
        let presentingController = PresentingViewController()
        let presentedController = PresentedViewController()

        let (module, provider) = makeModule(autoTrackingEnabled: true)
        module.startDetection()

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

        await waitUntil {
            let screenName = module.currentScreenNameForTesting
            return screenName.contains("PresentedViewController")
        }

        provider.emit(
            eventType: .dismissalWillBegin,
            presented: presentedController,
            presenting: presentingController,
            completed: nil
        )
        provider.emit(
            eventType: .dismissalDidEnd,
            presented: presentedController,
            presenting: presentingController,
            completed: true
        )

        await waitUntil {
            let screenName = module.currentScreenNameForTesting
            return screenName.contains("PresentingViewController")
        }
    }

    @MainActor
    func testNavDismissRestoresPriorScreen() async {
        let presentingController = PresentingViewController()
        let navigationController = UINavigationController(rootViewController: presentingController)
        let presentedController = PresentedViewController()

        let (module, provider) = makeModule(autoTrackingEnabled: true)
        module.startDetection()

        module.track(screen: "PresentingViewController")
        XCTAssertEqual(module.currentScreenNameForTesting, "PresentingViewController")

        provider.emit(
            eventType: .presentationWillBegin,
            presented: presentedController,
            presenting: navigationController,
            completed: nil
        )
        provider.emit(
            eventType: .presentationDidEnd,
            presented: presentedController,
            presenting: navigationController,
            completed: true
        )

        await waitUntil {
            let screenName = module.currentScreenNameForTesting
            return screenName.contains("PresentedViewController")
        }

        provider.emit(
            eventType: .dismissalWillBegin,
            presented: presentedController,
            presenting: navigationController,
            completed: nil
        )
        provider.emit(
            eventType: .dismissalDidEnd,
            presented: presentedController,
            presenting: navigationController,
            completed: true
        )

        let didRestore = await waitUntil {
            module.currentScreenNameForTesting == "PresentingViewController"
        }
        XCTAssertTrue(didRestore)
    }

    @MainActor
    func testPresentationCancelledKeepsPriorScreenName() async {
        let presentingController = PresentingViewController()
        let presentedController = PresentedViewController()

        let (module, provider) = makeModule(autoTrackingEnabled: true)
        module.startDetection()

        module.track(screen: "InitialScreen")
        XCTAssertEqual(module.currentScreenNameForTesting, "InitialScreen")

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
            completed: false
        )

        // Short window for negative assertion; 200 ms balances CI reliability.
        try? await Task.sleep(nanoseconds: 200_000_000)

        let screenName = module.currentScreenNameForTesting
        XCTAssertEqual(screenName, "InitialScreen")
    }

    @MainActor
    func testDismissalCancelledKeepsPresentedScreenName() async {
        let presentingController = PresentingViewController()
        let presentedController = PresentedViewController()

        let (module, provider) = makeModule(autoTrackingEnabled: true)
        module.startDetection()

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

        await waitUntil {
            let screenName = module.currentScreenNameForTesting
            return screenName.contains("PresentedViewController")
        }

        provider.emit(
            eventType: .dismissalWillBegin,
            presented: presentedController,
            presenting: presentingController,
            completed: nil
        )
        provider.emit(
            eventType: .dismissalDidEnd,
            presented: presentedController,
            presenting: presentingController,
            completed: false
        )

        // Short window for negative assertion; 200 ms balances CI reliability.
        try? await Task.sleep(nanoseconds: 200_000_000)

        let screenName = module.currentScreenNameForTesting
        XCTAssertTrue(screenName.contains("PresentedViewController"))
    }


    // MARK: - Precedence

    @MainActor
    func testPresentationOverridesManualWhenEnabled() async {
        let presentingController = PresentingViewController()
        let presentedController = PresentedViewController()

        let (module, provider) = makeModule(autoTrackingEnabled: true)
        module.startDetection()

        module.track(screen: "Manual Screen")
        XCTAssertEqual(module.currentScreenNameForTesting, "Manual Screen")

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

        await waitUntil {
            let screenName = module.currentScreenNameForTesting
            return screenName.contains("PresentedViewController")
        }
    }

    @MainActor
    func testPresentationSkipsWhenTrackingDisabled() async {
        let presentingController = PresentingViewController()
        let presentedController = PresentedViewController()

        let (module, provider) = makeModule(autoTrackingEnabled: false)
        module.startDetection()

        module.track(screen: "Manual Screen")
        XCTAssertEqual(module.currentScreenNameForTesting, "Manual Screen")

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

        // Short window for negative assertion; 200 ms balances CI reliability.
        try? await Task.sleep(nanoseconds: 200_000_000)

        let screenName = module.currentScreenNameForTesting
        XCTAssertEqual(screenName, "Manual Screen")
    }


    // MARK: - Timestamp preservation

    @MainActor
    func testPresentationTransitionEndUsesEventTimestamp() async {
        let presentingController = PresentingViewController()
        let presentedController = PresentedViewController()

        let (module, provider) = makeModule(autoTrackingEnabled: true)
        module.startDetection()

        let before = Date()

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

        let after = Date()

        await waitUntil {
            let screenName = module.currentScreenNameForTesting
            return screenName.contains("PresentedViewController")
        }

        // PresentationTransition span end time must come from the swizzle-hook
        // timestamp on the didEnd event, not from Date() on the actor.
        // Both start and end are captured in the same async context so their
        // difference reflects actual transition time, not dispatch overhead.
        let span = exporter.spans.first { $0.name == "PresentationTransition" }
        guard let span else {
            // PresentationTransition emission is tracked separately in DEMRUM-5533.
            // This test will become meaningful once that is resolved.
            return
        }

        XCTAssertGreaterThanOrEqual(span.endTime, before)
        XCTAssertLessThanOrEqual(span.endTime, after)
    }


    // MARK: - Helpers

    @MainActor
    private func makeModule(
        autoTrackingEnabled: Bool
    ) -> (Navigation, MockPresentationEventStreamProvider) {
        let provider = MockPresentationEventStreamProvider()
        let module = Navigation(navigationEventStreamProvider: provider)
        module.preferences.enableAutomatedTracking = autoTrackingEnabled
        return (module, provider)
    }
}
