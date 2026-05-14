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

import XCTest

/// UI tests that exercise navigation tracking scenarios in DevelApp.
///
/// These tests drive the app through screen transitions so the Splunk
/// navigation module emits spans. After the test run, use `rum-session.sh`
/// to query the resulting RUM session data and verify span attributes.
final class NavigationTrackingUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    // MARK: - Helpers

    /// Reads the session ID from the DemoHeaderView's label.
    /// Must be called while on a screen that displays DemoHeaderView.
    private func captureSessionId() -> String? {
        let label = app.staticTexts["sessionIdLabel"]
        guard label.waitForExistence(timeout: 5) else { return nil }
        let text = label.label // e.g. "Session ID: abc123def456"
        return text.replacingOccurrences(of: "Session ID: ", with: "")
    }

    /// Logs the session ID to the test output so we can grep it.
    private func logSessionId() {
        guard let sessionId = captureSessionId() else {
            XCTContext.runActivity(named: "Session ID") { activity in
                activity.add(XCTAttachment(string: "UNAVAILABLE"))
            }
            return
        }
        XCTContext.runActivity(named: "RUM_SESSION_ID: \(sessionId)") { _ in }
    }

    // MARK: - Smoke test

    func testAppLaunches() {
        XCTAssertTrue(app.navigationBars["Demo Screens"].waitForExistence(timeout: 10))
    }

    // MARK: - SwiftUI .trackScreen manual tracking

    /// Navigate: root -> Navigation Tracking Demo -> Basic Tracking -> back -> back
    /// Expected spans: DemoScreens, NavigationTrackingDemo, BasicTracking, NavigationTrackingDemo, DemoScreens
    func testBasicTrackScreenNavigation() {
        let navTrackingLink = app.buttons["navTrackingDemo"]
        XCTAssertTrue(navTrackingLink.waitForExistence(timeout: 5))
        navTrackingLink.tap()

        // Wait for Navigation Tracking screen
        XCTAssertTrue(app.navigationBars["Navigation Tracking"].waitForExistence(timeout: 5))

        // Tap into Basic Tracking
        let basicLink = app.buttons["basicTracking"]
        XCTAssertTrue(basicLink.waitForExistence(timeout: 5))
        basicLink.tap()

        // Verify we're on Basic Tracking screen
        XCTAssertTrue(app.navigationBars["Basic Tracking"].waitForExistence(timeout: 5))

        // Capture the session ID while DemoHeaderView is visible
        logSessionId()

        // Dwell so the span has a measurable duration
        sleep(2)

        // Navigate back
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Navigation Tracking"].waitForExistence(timeout: 5))

        sleep(1)

        // Navigate back to root
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Demo Screens"].waitForExistence(timeout: 5))
    }

    /// Navigate: root -> Navigation Tracking Demo -> Attributes Tracking -> back -> back
    /// Expected spans include custom attributes: demo.feature, demo.attributes
    func testAttributesTrackScreenNavigation() {
        let navTrackingLink = app.buttons["navTrackingDemo"]
        XCTAssertTrue(navTrackingLink.waitForExistence(timeout: 5))
        navTrackingLink.tap()

        XCTAssertTrue(app.navigationBars["Navigation Tracking"].waitForExistence(timeout: 5))

        // Tap into Attributes Tracking
        let attrLink = app.buttons["attributesTracking"]
        XCTAssertTrue(attrLink.waitForExistence(timeout: 5))
        attrLink.tap()

        XCTAssertTrue(app.navigationBars["Attributes Tracking"].waitForExistence(timeout: 5))

        logSessionId()

        sleep(2)

        // Back to Navigation Tracking
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Navigation Tracking"].waitForExistence(timeout: 5))

        sleep(1)

        // Back to root
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Demo Screens"].waitForExistence(timeout: 5))
    }

    /// Rapid back-and-forth between Basic and Attributes tracking screens.
    /// Tests deduplication: returning to the same screen should not double-fire.
    func testRapidNavigationDeduplication() {
        let navTrackingLink = app.buttons["navTrackingDemo"]
        XCTAssertTrue(navTrackingLink.waitForExistence(timeout: 5))
        navTrackingLink.tap()

        XCTAssertTrue(app.navigationBars["Navigation Tracking"].waitForExistence(timeout: 5))

        // Basic -> back -> Attributes -> back -> Basic -> back
        for identifier in ["basicTracking", "attributesTracking", "basicTracking"] {
            let link = app.buttons[identifier]
            XCTAssertTrue(link.waitForExistence(timeout: 5))
            link.tap()

            // Wait for the destination to appear
            sleep(1)

            // Navigate back
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(app.navigationBars["Navigation Tracking"].waitForExistence(timeout: 5))
        }

        // Back to root
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Demo Screens"].waitForExistence(timeout: 5))
    }

    // MARK: - UIKit automated tracking (DEMRUM-4776, DEMRUM-4778, DEMRUM-5203)

    /// Navigate to the UIKit demo and exercise push via UINavigationController.
    /// Expected automated spans: ShowVC for UIKitRootViewController, UIKitDetailViewController
    /// With NavigationEventProcessor, screen names should be rewritten:
    ///   UIKitRootViewController → "UIKitHome", UIKitDetailViewController → "DetailScreen"
    func testUIKitPushNavigation() {
        navigateToUIKitDemo()

        // Push Detail
        let pushButton = app.buttons["pushDetailButton"]
        XCTAssertTrue(pushButton.waitForExistence(timeout: 5))
        pushButton.tap()

        // Verify detail screen appeared
        let detailView = app.otherElements["uikitDetailView"]
        XCTAssertTrue(detailView.waitForExistence(timeout: 5))
        sleep(2)

        // Pop back
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let rootView = app.otherElements["uikitRootView"]
        XCTAssertTrue(rootView.waitForExistence(timeout: 5))
        sleep(2)
    }

    /// Navigate to UIKit demo and exercise modal presentation.
    /// Expected automated spans: PresentationTransition for UIKitModalViewController
    /// With NavigationEventProcessor, screen name should be "ModalScreen"
    func testUIKitModalPresentation() {
        navigateToUIKitDemo()

        // Present modal
        let presentButton = app.buttons["presentModalButton"]
        XCTAssertTrue(presentButton.waitForExistence(timeout: 5))
        presentButton.tap()

        // Verify modal appeared
        let modalView = app.otherElements["uikitModalView"]
        XCTAssertTrue(modalView.waitForExistence(timeout: 5))
        sleep(2)

        // Dismiss modal
        let dismissButton = app.buttons["dismissModalButton"]
        XCTAssertTrue(dismissButton.waitForExistence(timeout: 5))
        dismissButton.tap()

        // Verify we're back to root
        let rootView = app.otherElements["uikitRootView"]
        XCTAssertTrue(rootView.waitForExistence(timeout: 5))
        sleep(2)
    }

    /// Multi-level push then modal from a pushed screen.
    /// Exercises UINavigationController push + PresentationController from nested context.
    func testUIKitMultiLevelNavigation() {
        navigateToUIKitDemo()

        // Push to Second
        let pushSecondButton = app.buttons["pushSecondButton"]
        XCTAssertTrue(pushSecondButton.waitForExistence(timeout: 5))
        pushSecondButton.tap()

        let secondView = app.otherElements["uikitSecondView"]
        XCTAssertTrue(secondView.waitForExistence(timeout: 5))
        sleep(1)

        // Present modal from Second
        let presentFromSecond = app.buttons["presentModalFromSecondButton"]
        XCTAssertTrue(presentFromSecond.waitForExistence(timeout: 5))
        presentFromSecond.tap()

        let modalView = app.otherElements["uikitModalView"]
        XCTAssertTrue(modalView.waitForExistence(timeout: 5))
        sleep(1)

        // Dismiss modal
        app.buttons["dismissModalButton"].tap()
        XCTAssertTrue(secondView.waitForExistence(timeout: 5))
        sleep(1)

        // Pop back to root
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let rootView = app.otherElements["uikitRootView"]
        XCTAssertTrue(rootView.waitForExistence(timeout: 5))
        sleep(1)
    }

    /// Full scenario: exercises ALL navigation demo paths in a single session
    /// for maximum span coverage when validating with rum-session.sh.
    ///
    /// Phase 1: SwiftUI .trackScreen (Basic + Attributes)
    /// Phase 2: UIKit automated (push/pop, modal present/dismiss, multi-level)
    /// Phase 3: Dwell for span flush
    func testFullNavigationScenario() {
        // --- Phase 1: SwiftUI .trackScreen screens ---
        let navTrackingLink = app.buttons["navTrackingDemo"]
        XCTAssertTrue(navTrackingLink.waitForExistence(timeout: 5))
        navTrackingLink.tap()
        XCTAssertTrue(app.navigationBars["Navigation Tracking"].waitForExistence(timeout: 5))
        sleep(1)

        // Basic Tracking
        app.buttons["basicTracking"].tap()
        XCTAssertTrue(app.navigationBars["Basic Tracking"].waitForExistence(timeout: 5))

        // Capture the session ID while DemoHeaderView is visible
        logSessionId()

        sleep(2)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Navigation Tracking"].waitForExistence(timeout: 5))

        // Attributes Tracking
        app.buttons["attributesTracking"].tap()
        XCTAssertTrue(app.navigationBars["Attributes Tracking"].waitForExistence(timeout: 5))
        sleep(2)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Navigation Tracking"].waitForExistence(timeout: 5))

        // Back to root
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Demo Screens"].waitForExistence(timeout: 5))
        sleep(1)

        // --- Phase 2: UIKit automated tracking ---
        navigateToUIKitDemo()

        // Push Detail → dwell → pop
        app.buttons["pushDetailButton"].tap()
        XCTAssertTrue(app.otherElements["uikitDetailView"].waitForExistence(timeout: 5))
        sleep(2)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.otherElements["uikitRootView"].waitForExistence(timeout: 5))
        sleep(1)

        // Present Modal → dwell → dismiss
        app.buttons["presentModalButton"].tap()
        XCTAssertTrue(app.otherElements["uikitModalView"].waitForExistence(timeout: 5))
        sleep(2)
        app.buttons["dismissModalButton"].tap()
        XCTAssertTrue(app.otherElements["uikitRootView"].waitForExistence(timeout: 5))
        sleep(1)

        // Push Second → Present Modal from Second → dismiss → pop
        app.buttons["pushSecondButton"].tap()
        XCTAssertTrue(app.otherElements["uikitSecondView"].waitForExistence(timeout: 5))
        sleep(1)
        app.buttons["presentModalFromSecondButton"].tap()
        XCTAssertTrue(app.otherElements["uikitModalView"].waitForExistence(timeout: 5))
        sleep(1)
        app.buttons["dismissModalButton"].tap()
        XCTAssertTrue(app.otherElements["uikitSecondView"].waitForExistence(timeout: 5))
        sleep(1)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.otherElements["uikitRootView"].waitForExistence(timeout: 5))

        // --- Phase 3: Dwell on UIKit root to let spans flush to backend ---
        sleep(5)
    }

    // MARK: - UIKit navigation helpers

    /// Navigates from the root Demo Screens list to the UIKit Navigation Demo.
    private func navigateToUIKitDemo() {
        let uikitLink = app.buttons["uikitNavDemo"]
        XCTAssertTrue(uikitLink.waitForExistence(timeout: 5))
        uikitLink.tap()

        // Wait for the UIKit root view controller to appear
        let rootView = app.otherElements["uikitRootView"]
        XCTAssertTrue(rootView.waitForExistence(timeout: 5))
    }
}
