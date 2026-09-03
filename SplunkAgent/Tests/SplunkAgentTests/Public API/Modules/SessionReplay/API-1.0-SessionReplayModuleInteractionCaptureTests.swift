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

import SplunkAgent
import XCTest

final class SessionReplayInteractionCaptureTests: XCTestCase {

    // MARK: - Default state

    func testInitialValues() {
        assertAllCategoriesEnabled(makeCapture())
    }


    // MARK: - Category properties

    func testSetters() {
        let capture = makeCapture()

        capture.isKeyboardEnabled = false
        capture.isTouchEnabled = false
        capture.isGestureEnabled = false
        capture.isFocusEnabled = false
        capture.isRageTapEnabled = false

        assertAllCategoriesDisabled(capture)
    }


    // MARK: - Bulk updates

    func testDisableAll() {
        let capture = makeCapture()

        capture.disableAll()

        assertAllCategoriesDisabled(capture)
    }

    func testEnableAll() {
        let capture = makeCapture()
        capture.disableAll()

        capture.enableAll()

        assertAllCategoriesEnabled(capture)
    }


    // MARK: - Codable

    func testPreferencesCodableRoundTripPreservesInteractionCapture() throws {
        let preferences = SessionReplayPreferences(renderingMode: .wireframeOnly)
        let capture = preferences.interactionCapture
        capture.isKeyboardEnabled = false
        capture.isTouchEnabled = true
        capture.isGestureEnabled = false
        capture.isFocusEnabled = true
        capture.isRageTapEnabled = false

        let data = try JSONEncoder().encode(preferences)
        let decodedPreferences = try JSONDecoder().decode(SessionReplayPreferences.self, from: data)
        let decodedCapture = decodedPreferences.interactionCapture

        XCTAssertEqual(decodedPreferences.renderingMode, .wireframeOnly)
        XCTAssertFalse(decodedCapture.isKeyboardEnabled)
        XCTAssertTrue(decodedCapture.isTouchEnabled)
        XCTAssertFalse(decodedCapture.isGestureEnabled)
        XCTAssertTrue(decodedCapture.isFocusEnabled)
        XCTAssertFalse(decodedCapture.isRageTapEnabled)
    }

    func testPreferencesDecodingLegacyPayloadUsesInteractionCaptureDefaults() throws {
        let data = try JSONEncoder().encode(LegacyPreferences(renderingMode: .native))

        let preferences = try JSONDecoder().decode(SessionReplayPreferences.self, from: data)

        XCTAssertEqual(preferences.renderingMode, .native)
        assertAllCategoriesEnabled(preferences.interactionCapture)
    }

    func testPreferencesDecodingPartialInteractionCaptureUsesCategoryDefaults() throws {
        let data = Data(
            #"{"interactionCapture":{"isKeyboardEnabled":false,"isRageTapEnabled":false}}"#.utf8
        )

        let capture = try JSONDecoder()
            .decode(SessionReplayPreferences.self, from: data)
            .interactionCapture

        XCTAssertFalse(capture.isKeyboardEnabled)
        XCTAssertTrue(capture.isTouchEnabled)
        XCTAssertTrue(capture.isGestureEnabled)
        XCTAssertTrue(capture.isFocusEnabled)
        XCTAssertFalse(capture.isRageTapEnabled)
    }


    // MARK: - Fixtures

    private func makeCapture() -> any SessionReplayModuleInteractionCapture {
        SessionReplayPreferences(renderingMode: .native).interactionCapture
    }

    private struct LegacyPreferences: Encodable {
        let renderingMode: RenderingMode?
    }


    // MARK: - Assertions

    private func assertAllCategoriesEnabled(
        _ capture: any SessionReplayModuleInteractionCapture,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(capture.isKeyboardEnabled, file: file, line: line)
        XCTAssertTrue(capture.isTouchEnabled, file: file, line: line)
        XCTAssertTrue(capture.isGestureEnabled, file: file, line: line)
        XCTAssertTrue(capture.isFocusEnabled, file: file, line: line)
        XCTAssertTrue(capture.isRageTapEnabled, file: file, line: line)
    }

    private func assertAllCategoriesDisabled(
        _ capture: any SessionReplayModuleInteractionCapture,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertFalse(capture.isKeyboardEnabled, file: file, line: line)
        XCTAssertFalse(capture.isTouchEnabled, file: file, line: line)
        XCTAssertFalse(capture.isGestureEnabled, file: file, line: line)
        XCTAssertFalse(capture.isFocusEnabled, file: file, line: line)
        XCTAssertFalse(capture.isRageTapEnabled, file: file, line: line)
    }
}
