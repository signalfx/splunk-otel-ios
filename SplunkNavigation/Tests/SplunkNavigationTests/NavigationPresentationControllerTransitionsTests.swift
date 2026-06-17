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
@testable @_spi(SplunkInternal) import SplunkNavigation // swiftlint:disable:this sorted_imports

final class NavigationPresentationTransitionsTests: XCTestCase {

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


    // MARK: - No prior screen

    @MainActor
    func testNavDismissWithNoPriorScreenResetsToUnknown() async {
        let presentingController = PresentingViewController()
        let navigationController = UINavigationController(rootViewController: presentingController)
        let presentedController = PresentedViewController()

        let (module, provider) = makeModule(autoTrackingEnabled: true)

        let observer = ScreenNameObserverRecorder()
        module.setScreenNameObserver { [observer] name in
            observer.append(name)
        }

        module.startDetection()

        // No screen has been tracked yet — storedScreenState is nil.

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

        let didPresent = await waitUntil {
            module.currentScreenNameForTesting.contains("PresentedViewController")
        }
        XCTAssertTrue(didPresent, "Screen must become PresentedViewController before dismissal")
        XCTAssertTrue(
            observer.values.contains { $0.contains("PresentedViewController") },
            "Observer must have seen PresentedViewController before dismissal"
        )

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

        // After dismissal the store and the observer must both reflect "unknown",
        // not remain stuck on the dismissed modal's name.
        let didReset = await waitUntil {
            module.currentScreenNameForTesting == "unknown"
        }
        XCTAssertTrue(didReset)
        XCTAssertEqual(observer.last, "unknown", "Observer must be notified with 'unknown' on dismissal with no prior screen")
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
