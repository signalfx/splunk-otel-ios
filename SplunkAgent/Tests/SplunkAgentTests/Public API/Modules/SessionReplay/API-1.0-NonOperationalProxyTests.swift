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

final class SessionReplayAPI10NoOpProxyTests: XCTestCase {

    // MARK: - Private

    private let moduleProxy = SessionReplayTestBuilder.buildNonOperational()


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

        let encodedPreferences = try? JSONEncoder().encode(moduleProxy.preferences as? SessionReplayPreferences)
        XCTAssertNotNil(encodedPreferences)

        if let encodedPreferences = encodedPreferences {
            XCTAssertNoThrow(try JSONDecoder().decode(SessionReplayPreferences.self, from: encodedPreferences))
        }
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

    func testDefaultStatus() throws {
        let status = moduleProxy.state.status

        XCTAssertNotNil(status)
        XCTAssertEqual(status, .notRecording(.remotelyDisabled))
    }


    // MARK: - Sensitivity

    func testSensitivity() throws {

        moduleProxy.sensitivity[UIView()] = true
        moduleProxy.sensitivity[UIView.self] = true

        moduleProxy.sensitivity
            .set(UIView(), true)
            .set(UIView.self, true)

        _ = moduleProxy.sensitivity[UIView()]
        _ = moduleProxy.sensitivity[UIView.self]
    }

    func testUIViewTypeSensitivityExtension() throws {
        let viewType = UIView.self

        moduleProxy.sensitivity[viewType] = true

        let isSensitive = moduleProxy.sensitivity[viewType]
        XCTAssertNil(isSensitive)
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
        maskElements.append(
            MaskElement(rect: CGRect(x: 0, y: 0, width: 100, height: 100), type: .covering)
        )

        let recordingMask = RecordingMask(elements: maskElements)

        moduleProxy.recordingMask = recordingMask
        _ = moduleProxy.recordingMask(recordingMask)

        XCTAssertNil(moduleProxy.recordingMask)
    }
}
