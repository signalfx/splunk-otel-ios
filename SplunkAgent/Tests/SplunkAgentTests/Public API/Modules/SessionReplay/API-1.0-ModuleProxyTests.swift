//
/*
Copyright 2024 Splunk Inc.

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

@testable import SplunkAgent
import XCTest

final class SessionReplayAPI10ModuleProxyTests: XCTestCase {

    // MARK: - Private

    private let moduleProxy = SessionReplayTestBuilder.buildDefault()


    // MARK: - Recording

    func testStart() throws {
        XCTAssertNotNil(moduleProxy.start())
    }

    func testStop() throws {
        XCTAssertNotNil(moduleProxy.stop())
    }


    // MARK: - Preferences

    // Temporarily removed with Rendering Modes.

    // swiftformat:disable indent

    /*
    func testPreferences() throws {
        let preferences = SessionReplayPreferences()
            .renderingMode(.wireframe)

        moduleProxy.preferences = preferences
        moduleProxy.preferences(preferences)

        let readPreferences = moduleProxy.preferences
        let encodedPreferences = try? JSONEncoder().encode(readPreferences as? SessionReplayPreferences)
        XCTAssertNotNil(encodedPreferences)

        if let encodedPreferences = encodedPreferences {
            XCTAssertNoThrow(try JSONDecoder().decode(SessionReplayPreferences.self, from: encodedPreferences))
        }
    }

    func testPreferences_givenAllRenderingModes() throws {
        _ = SessionReplayPreferences()
            .renderingMode(.wireframe)
            .renderingMode(.native)
            .renderingMode(.noRendering)

        _ = SessionReplayPreferences(renderingMode: .wireframe)
        _ = SessionReplayPreferences(renderingMode: .native)
        _ = SessionReplayPreferences(renderingMode: .noRendering)
    }
     */

    // swiftformat:enable indent


    // MARK: - State

    func testState() throws {
        let state = moduleProxy.state

        XCTAssertNotNil(state.status)

        // Temporarily removed with Rendering Modes.
        // XCTAssertNotNil(state.renderingMode)

        XCTAssertNotNil(state.isRecording)
    }


    // MARK: - Status

    func testStatus() throws {
        switch moduleProxy.state.status {
        case .recording:
            break

        case .notRecording(.notStarted):
            break

        case .notRecording(.stopped):
            break

        case .notRecording(.projectLimitReached):
            break

        case .notRecording(.internalError):
            break

        case .notRecording(.swiftUIPreviewContext):
            break

        case .notRecording(.unsupportedPlatform):
            break

        case .notRecording(.diskCacheCapacityOverreached):
            break

        case .notRecording(.remotelyDisabled):
            break
        }
    }


    // MARK: - Sensitivity

    func testSensitivity() throws {

        moduleProxy.sensitivity[UIView()] = true
        moduleProxy.sensitivity[UIView()] = false
        moduleProxy.sensitivity[UIView()] = nil

        moduleProxy.sensitivity[UIView.self] = true
        moduleProxy.sensitivity[UIView.self] = false
        moduleProxy.sensitivity[UIView.self] = nil

        moduleProxy.sensitivity
            .set(UIView(), true)
            .set(UIView(), false)
            .set(UIView(), nil)
            .set(UIView.self, true)
            .set(UIView.self, false)
            .set(UIView.self, nil)

        _ = moduleProxy.sensitivity[UIView()]
        _ = moduleProxy.sensitivity[UIView.self]
    }

    func testUIViewTypeSensitivityExtension() throws {
        let viewType = UIView.self

        moduleProxy.sensitivity[viewType] = true

        let isSensitive = moduleProxy.sensitivity[viewType]
        XCTAssertNotNil(isSensitive)
    }


    // MARK: - Rendering Mode

    // Temporarily removed with Rendering Modes.

    // swiftformat:disable indent

    /*
    func testRenderingModes() throws {
        let renderingMode = RenderingMode.default
        switch renderingMode {
        case .native:
            break

        case .wireframe:
            break

        case .noRendering:
            break
        }
    }

    func testDefaultRenderingMode() throws {
        let defaultRenderingMode = RenderingMode.default

        XCTAssertEqual(defaultRenderingMode, .native)
    }
     */

    // swiftformat:enable indent


    // MARK: - Recording Masks

    func testRecordingMask() throws {
        var maskElements = [MaskElement]()

        maskElements.append(MaskElement(rect: CGRect(x: 0, y: 0, width: 100, height: 100), type: .covering))
        maskElements.append(MaskElement(rect: CGRect(x: 50, y: 120, width: 100, height: 100), type: .erasing))

        let recordingMask = RecordingMask(elements: maskElements)

        moduleProxy.recordingMask = recordingMask
        _ = moduleProxy.recordingMask(recordingMask)

        XCTAssertNotNil(moduleProxy.recordingMask)
        XCTAssertEqual(moduleProxy.recordingMask, recordingMask)
    }

    func testEmptyRecordingMask() throws {
        let emptyRecordingMask = RecordingMask(elements: [])
        let filledRecordingMask = RecordingMask(
            elements: [
                MaskElement(rect: CGRect(x: 0, y: 0, width: 100, height: 100), type: .covering)
            ]
        )

        moduleProxy.recordingMask = emptyRecordingMask
        XCTAssertNil(moduleProxy.recordingMask)

        moduleProxy.recordingMask = filledRecordingMask
        XCTAssertNotNil(moduleProxy.recordingMask)

        moduleProxy.recordingMask?.elements.removeAll()
        XCTAssertNil(moduleProxy.recordingMask)
    }


    // MARK: - Agent session lifecycle

    func testSessionRotation() throws {
        let initialCount = moduleProxy.newSessionsCount

        sendSimulatedNotification(DefaultSession.sessionDidResetNotification)
        simulateMainThreadWait(duration: 0.5)

        // There should be processed one request to rotate session in module
        XCTAssertEqual(initialCount, 0)
        XCTAssertEqual(moduleProxy.newSessionsCount, 1)
    }
}
