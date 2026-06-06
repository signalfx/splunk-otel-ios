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

/// UI tests that exercise navigation and lifecycle instrumentation scenarios in DevelApp.
final class NavigationTrackingUITests: XCTestCase {

    // MARK: - Private

    private var app = XCUIApplication()


    // MARK: - Test lifecycle

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }


    // MARK: - Smoke test

    func testAppLaunches() {
        XCTAssertTrue(app.navigationBars["Demo Screens"].waitForExistence(timeout: 10))
    }


    // MARK: - SwiftUI .trackScreen manual tracking

    func testBasicTrackScreenNavigation() {
        navigateToNavigationTrackingDemo()

        let basicLink = app.buttons["basicTracking"]
        XCTAssertTrue(basicLink.waitForExistence(timeout: 5))
        basicLink.tap()

        XCTAssertTrue(app.navigationBars["Basic Tracking"].waitForExistence(timeout: 5))
        logSessionId()
        sleep(2)

        tapBackButton()
        XCTAssertTrue(app.navigationBars["Navigation Tracking"].waitForExistence(timeout: 5))

        tapBackButton()
        XCTAssertTrue(app.navigationBars["Demo Screens"].waitForExistence(timeout: 5))
    }

    func testAttributesTrackScreenNavigation() {
        navigateToNavigationTrackingDemo()

        let attrLink = app.buttons["attributesTracking"]
        XCTAssertTrue(attrLink.waitForExistence(timeout: 5))
        attrLink.tap()

        XCTAssertTrue(app.navigationBars["Attributes Tracking"].waitForExistence(timeout: 5))
        logSessionId()
        sleep(2)

        tapBackButton()
        XCTAssertTrue(app.navigationBars["Navigation Tracking"].waitForExistence(timeout: 5))

        tapBackButton()
        XCTAssertTrue(app.navigationBars["Demo Screens"].waitForExistence(timeout: 5))
    }

    func testRapidNavigationDeduplication() {
        navigateToNavigationTrackingDemo()

        for identifier in ["basicTracking", "attributesTracking", "basicTracking"] {
            let link = app.buttons[identifier]
            XCTAssertTrue(link.waitForExistence(timeout: 5))
            link.tap()
            sleep(1)

            tapBackButton()
            XCTAssertTrue(app.navigationBars["Navigation Tracking"].waitForExistence(timeout: 5))
        }

        tapBackButton()
        XCTAssertTrue(app.navigationBars["Demo Screens"].waitForExistence(timeout: 5))
    }


    // MARK: - UIKit automated tracking and lifecycle point events

    func testUIKitPushNavigation() {
        navigateToUIKitDemo()

        app.buttons["pushDetailButton"].tap()
        XCTAssertTrue(app.otherElements["uikitDetailView"].waitForExistence(timeout: 5))
        sleep(2)

        tapBackButton()
        XCTAssertTrue(app.otherElements["uikitRootView"].waitForExistence(timeout: 5))
        sleep(2)
    }

    func testUIKitModalPresentation() {
        navigateToUIKitDemo()

        app.buttons["presentModalButton"].tap()
        XCTAssertTrue(app.otherElements["uikitModalView"].waitForExistence(timeout: 5))
        sleep(2)

        app.buttons["dismissModalButton"].tap()
        XCTAssertTrue(app.otherElements["uikitRootView"].waitForExistence(timeout: 5))
        sleep(2)
    }

    func testUIKitMultiLevelNavigation() {
        navigateToUIKitDemo()

        app.buttons["pushSecondButton"].tap()
        XCTAssertTrue(app.otherElements["uikitSecondView"].waitForExistence(timeout: 5))
        sleep(1)

        app.buttons["presentModalFromSecondButton"].tap()
        XCTAssertTrue(app.otherElements["uikitModalView"].waitForExistence(timeout: 5))
        sleep(1)

        app.buttons["dismissModalButton"].tap()
        XCTAssertTrue(app.otherElements["uikitSecondView"].waitForExistence(timeout: 5))
        sleep(1)

        tapBackButton()
        XCTAssertTrue(app.otherElements["uikitRootView"].waitForExistence(timeout: 5))
        sleep(1)
    }

    func testUIKitLifecyclePointEventsScenario() {
        navigateToUIKitDemo()
        logSessionId()

        app.buttons["pushDetailButton"].tap()
        XCTAssertTrue(app.otherElements["uikitDetailView"].waitForExistence(timeout: 5))
        sleep(2)

        tapBackButton()
        XCTAssertTrue(app.otherElements["uikitRootView"].waitForExistence(timeout: 5))
        sleep(1)

        app.buttons["presentModalButton"].tap()
        XCTAssertTrue(app.otherElements["uikitModalView"].waitForExistence(timeout: 5))
        sleep(2)

        app.buttons["dismissModalButton"].tap()
        XCTAssertTrue(app.otherElements["uikitRootView"].waitForExistence(timeout: 5))
        sleep(5)
    }

    func testFullNavigationScenario() {
        navigateToNavigationTrackingDemo()

        app.buttons["basicTracking"].tap()
        XCTAssertTrue(app.navigationBars["Basic Tracking"].waitForExistence(timeout: 5))
        logSessionId()
        sleep(2)

        tapBackButton()
        XCTAssertTrue(app.navigationBars["Navigation Tracking"].waitForExistence(timeout: 5))

        app.buttons["attributesTracking"].tap()
        XCTAssertTrue(app.navigationBars["Attributes Tracking"].waitForExistence(timeout: 5))
        sleep(2)

        tapBackButton()
        XCTAssertTrue(app.navigationBars["Navigation Tracking"].waitForExistence(timeout: 5))

        tapBackButton()
        XCTAssertTrue(app.navigationBars["Demo Screens"].waitForExistence(timeout: 5))
        sleep(1)

        navigateToUIKitDemo()

        app.buttons["pushDetailButton"].tap()
        XCTAssertTrue(app.otherElements["uikitDetailView"].waitForExistence(timeout: 5))
        sleep(2)

        tapBackButton()
        XCTAssertTrue(app.otherElements["uikitRootView"].waitForExistence(timeout: 5))
        sleep(1)

        app.buttons["presentModalButton"].tap()
        XCTAssertTrue(app.otherElements["uikitModalView"].waitForExistence(timeout: 5))
        sleep(2)

        app.buttons["dismissModalButton"].tap()
        XCTAssertTrue(app.otherElements["uikitRootView"].waitForExistence(timeout: 5))
        sleep(1)

        app.buttons["pushSecondButton"].tap()
        XCTAssertTrue(app.otherElements["uikitSecondView"].waitForExistence(timeout: 5))
        sleep(1)

        app.buttons["presentModalFromSecondButton"].tap()
        XCTAssertTrue(app.otherElements["uikitModalView"].waitForExistence(timeout: 5))
        sleep(1)

        app.buttons["dismissModalButton"].tap()
        XCTAssertTrue(app.otherElements["uikitSecondView"].waitForExistence(timeout: 5))
        sleep(1)

        tapBackButton()
        XCTAssertTrue(app.otherElements["uikitRootView"].waitForExistence(timeout: 5))
        sleep(5)
    }


    // MARK: - Helpers

    private func navigateToNavigationTrackingDemo() {
        let navTrackingLink = app.buttons["navTrackingDemo"]
        XCTAssertTrue(navTrackingLink.waitForExistence(timeout: 5))
        navTrackingLink.tap()
        XCTAssertTrue(app.navigationBars["Navigation Tracking"].waitForExistence(timeout: 5))
    }

    private func navigateToUIKitDemo() {
        let uikitLink = app.buttons["uikitNavDemo"]
        XCTAssertTrue(uikitLink.waitForExistence(timeout: 5))
        uikitLink.tap()

        let rootView = app.otherElements["uikitRootView"]
        XCTAssertTrue(rootView.waitForExistence(timeout: 5))
    }

    private func tapBackButton() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    private func captureSessionId() -> String? {
        let label = app.staticTexts["sessionIdLabel"]
        guard label.waitForExistence(timeout: 5) else {
            return nil
        }

        return label.label.replacingOccurrences(of: "Session ID: ", with: "")
    }

    private func logSessionId() {
        guard let sessionId = captureSessionId() else {
            XCTContext.runActivity(named: "Session ID") { activity in
                activity.add(XCTAttachment(string: "UNAVAILABLE"))
            }
            return
        }

        XCTContext.runActivity(named: "RUM_SESSION_ID: \(sessionId)") { _ in }
    }
}
