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

// Regression tests for DEMRUM-5533: PresentationTransition span absent when the
// nav detection loop's viewDidLoad/viewDidAppear races with the presentation path.
//
// In UIKit, presentationWillBegin/dismissalWillBegin always precede the nav
// loop's lifecycle events (viewDidLoad fires after presentationWillBegin; the
// presenting VC's viewDidAppear fires after dismissalWillBegin). Tests model
// this ordering by waiting for the presentation managed target to be registered
// before injecting nav-loop events -- the same guarantee UIKit provides.

final class NavigationPresentationSpanEmissionTests: XCTestCase {

    // MARK: - Private

    private var exporter = CollectingSpanExporter()
    private var originalTracerProvider: TracerProvider = OpenTelemetry.instance.tracerProvider


    // MARK: - Tests lifecycle

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


    // MARK: - Present

    @MainActor
    func testPresentationTransitionSpanEmitsWithoutShowVCWhenNavEventsArrive() async {
        let presentingController = PresentingViewController()
        let presentedController = PresentedViewController()

        let provider = MockCombinedEventStreamProvider()
        let navigation = Navigation(navigationEventStreamProvider: provider)
        navigation.preferences.enableAutomatedTracking = true
        navigation.startDetection()

        // presentationWillBegin registers the presented VC as a managed target before
        // UIKit fires viewDidLoad/viewDidAppear for that VC.
        provider.emitPresentation(
            eventType: .presentationWillBegin,
            presented: presentedController,
            presenting: presentingController,
            completed: nil
        )

        // Wait for the presentation loop to register the managed target -- mirroring
        // the UIKit guarantee that presentationWillBegin precedes viewDidLoad.
        let presentedIdentifier = ObjectIdentifier(presentedController)
        let registered = await waitUntil {
            await navigation.model.isPresentationManagedTarget(presentedIdentifier)
        }
        XCTAssertTrue(registered, "Presented VC must be registered as presentation-managed before nav events arrive")

        // Nav loop events that UIKit fires after the presentation has begun.
        provider.emitNavigation(type: .viewDidLoad, controller: presentedController)
        provider.emitNavigation(type: .viewDidAppear, controller: presentedController)

        provider.emitPresentation(
            eventType: .presentationDidEnd,
            presented: presentedController,
            presenting: presentingController,
            completed: true
        )

        let didEmit = await waitUntil {
            self.exporter.spans.contains { $0.name == "PresentationTransition" }
        }
        XCTAssertTrue(didEmit, "PresentationTransition span must be emitted")

        // Allow settling time before asserting absence of ShowVC.
        try? await Task.sleep(nanoseconds: 200_000_000)

        let showVCSpans = exporter.spans.filter { $0.name == "ShowVC" }
        XCTAssertTrue(
            showVCSpans.isEmpty,
            "Nav-loop lifecycle events for the presented VC must not produce a ShowVC span"
        )
    }

    @MainActor
    func testPresentationTransitionSpanEmittedExactlyOnce() async {
        let presentingController = PresentingViewController()
        let presentedController = PresentedViewController()

        let provider = MockCombinedEventStreamProvider()
        let navigation = Navigation(navigationEventStreamProvider: provider)
        navigation.preferences.enableAutomatedTracking = true
        navigation.startDetection()

        provider.emitPresentation(
            eventType: .presentationWillBegin,
            presented: presentedController,
            presenting: presentingController,
            completed: nil
        )

        let presentedIdentifier = ObjectIdentifier(presentedController)
        await waitUntil {
            await navigation.model.isPresentationManagedTarget(presentedIdentifier)
        }

        provider.emitNavigation(type: .viewDidLoad, controller: presentedController)
        provider.emitNavigation(type: .viewDidAppear, controller: presentedController)

        provider.emitPresentation(
            eventType: .presentationDidEnd,
            presented: presentedController,
            presenting: presentingController,
            completed: true
        )

        await waitUntil {
            self.exporter.spans.contains { $0.name == "PresentationTransition" }
        }

        try? await Task.sleep(nanoseconds: 200_000_000)

        let transitionSpans = exporter.spans.filter { $0.name == "PresentationTransition" }
        XCTAssertEqual(transitionSpans.count, 1, "Exactly one PresentationTransition span must be emitted")
    }


    // MARK: - Dismiss

    @MainActor
    func testDismissalTransitionSpanEmits() async {
        let fixture = await makeModuleAfterPresentation()

        fixture.emitPresentation(eventType: .dismissalWillBegin, completed: nil)

        let presentingIdentifier = ObjectIdentifier(fixture.presentingController)
        let registered = await waitUntil {
            await fixture.navigation.model.isPresentationManagedTarget(presentingIdentifier)
        }
        XCTAssertTrue(registered, "Presenting VC must be registered as presentation-managed before nav events arrive")

        fixture.emitNavigation(type: .viewDidAppear, controller: fixture.presentingController)
        fixture.emitPresentation(eventType: .dismissalDidEnd, completed: true)

        let didEmit = await waitUntil {
            self.exporter.spans.contains { $0.name == "PresentationTransition" }
        }
        XCTAssertTrue(didEmit, "PresentationTransition span must be emitted on dismissal")
    }

    @MainActor
    func testDismissalNavLoopViewDidAppearDoesNotProduceShowVC() async {
        let fixture = await makeModuleAfterPresentation()

        fixture.emitPresentation(eventType: .dismissalWillBegin, completed: nil)

        let presentingIdentifier = ObjectIdentifier(fixture.presentingController)
        await waitUntil {
            await fixture.navigation.model.isPresentationManagedTarget(presentingIdentifier)
        }

        fixture.emitNavigation(type: .viewDidAppear, controller: fixture.presentingController)
        fixture.emitPresentation(eventType: .dismissalDidEnd, completed: true)

        await waitUntil {
            self.exporter.spans.contains { $0.name == "PresentationTransition" }
        }

        try? await Task.sleep(nanoseconds: 200_000_000)

        let showVCSpans = exporter.spans.filter { $0.name == "ShowVC" }
        XCTAssertTrue(
            showVCSpans.isEmpty,
            "Nav-loop viewDidAppear for the presenting VC during dismissal must not produce a ShowVC span"
        )
    }


    // MARK: - Helpers

    /// Builds a module, drives a full present cycle so screen state is set, resets
    /// the exporter, and returns the fixture ready for a dismissal test.
    @MainActor
    private func makeModuleAfterPresentation() async -> SpanEmissionDismissalFixture {
        let fixture = SpanEmissionDismissalFixture()
        fixture.navigation.preferences.enableAutomatedTracking = true
        fixture.navigation.startDetection()

        fixture.emitPresentation(eventType: .presentationWillBegin, completed: nil)
        let presentedIdentifier = ObjectIdentifier(fixture.presentedController)
        await waitUntil {
            await fixture.navigation.model.isPresentationManagedTarget(presentedIdentifier)
        }
        fixture.emitNavigation(type: .viewDidLoad, controller: fixture.presentedController)
        fixture.emitNavigation(type: .viewDidAppear, controller: fixture.presentedController)
        fixture.emitPresentation(eventType: .presentationDidEnd, completed: true)
        await waitUntil {
            self.exporter.spans.contains { $0.name == "PresentationTransition" }
        }
        exporter.reset()

        return fixture
    }
}


// MARK: - SpanEmissionDismissalFixture

/// Pairs a Navigation module with its combined provider and fixed controller
/// instances so dismissal tests can reference all three without threading them
/// through multiple return values.
@MainActor
private final class SpanEmissionDismissalFixture {
    let presentingController = PresentingViewController()
    let presentedController = PresentedViewController()
    let provider = MockCombinedEventStreamProvider()
    let navigation: Navigation

    init() {
        navigation = Navigation(navigationEventStreamProvider: provider)
    }

    func emitPresentation(eventType: PresentationActionEventType, completed: Bool?) {
        provider.emitPresentation(
            eventType: eventType,
            presented: presentedController,
            presenting: presentingController,
            completed: completed
        )
    }

    func emitNavigation(type: NavigationActionEventType, controller: UIViewController) {
        provider.emitNavigation(type: type, controller: controller)
    }
}
