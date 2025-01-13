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

@testable import CiscoRUM
@testable import CiscoSessionReplay

import XCTest

final class SessionReplayAPI10TypeConversionsTests: XCTestCase {

    // MARK: - Rendering mode

    // Temporarily removed with Rendering Modes.

    // swiftformat:disable indent

    /*
    func testRenderingModesToProxyConversion() throws {
        /* From module to proxy */
        var moduleRenderingMode: MRUMSessionReplayRenderingMode = .default
        var proxyRenderingMode: CiscoRUM.RenderingMode = .default

        // Test for all possible options
        proxyRenderingMode = .init(with: moduleRenderingMode)
        XCTAssertEqual(proxyRenderingMode, .default)

        moduleRenderingMode = .native
        proxyRenderingMode = .init(with: moduleRenderingMode)
        XCTAssertEqual(proxyRenderingMode, .native)

        moduleRenderingMode = .wireframe
        proxyRenderingMode = .init(with: moduleRenderingMode)
        XCTAssertEqual(proxyRenderingMode, .wireframe)

        moduleRenderingMode = .noRendering
        proxyRenderingMode = .init(with: moduleRenderingMode)
        XCTAssertEqual(proxyRenderingMode, .noRendering)
    }

    func testRenderingModesToModuleConversion() throws {
        /* From proxy to module */
        var proxyRenderingMode: CiscoRUM.RenderingMode = .default
        var srRenderingMode = proxyRenderingMode.srRenderingMode
        XCTAssertEqual(srRenderingMode, .default)

        proxyRenderingMode = .native
        srRenderingMode = proxyRenderingMode.srRenderingMode
        XCTAssertEqual(srRenderingMode, .native)

        proxyRenderingMode = .wireframe
        srRenderingMode = proxyRenderingMode.srRenderingMode
        XCTAssertEqual(srRenderingMode, .wireframe)

        proxyRenderingMode = .noRendering
        srRenderingMode = proxyRenderingMode.srRenderingMode
        XCTAssertEqual(srRenderingMode, .noRendering)
    }
     */

    // swiftformat:enable indent


    // MARK: - Status

    func testStatusToProxyConversion() throws {
        /* From module to proxy */
        var moduleStatus: MRUMSessionReplayStatus = .recording
        var proxyStatus: CiscoRUM.SessionReplayStatus = .recording


        // Recording
        proxyStatus = .init(srStatus: moduleStatus)
        XCTAssertEqual(proxyStatus, .recording)


        // Not recording
        moduleStatus = .notRecording(.diskCacheCapacityOverreached)
        proxyStatus = .init(srStatus: moduleStatus)
        XCTAssertEqual(proxyStatus, .notRecording(.diskCacheCapacityOverreached))

        moduleStatus = .notRecording(.internalError)
        proxyStatus = .init(srStatus: moduleStatus)
        XCTAssertEqual(proxyStatus, .notRecording(.internalError))

        moduleStatus = .notRecording(.notStarted)
        proxyStatus = .init(srStatus: moduleStatus)
        XCTAssertEqual(proxyStatus, .notRecording(.notStarted))

        moduleStatus = .notRecording(.projectLimitReached)
        proxyStatus = .init(srStatus: moduleStatus)
        XCTAssertEqual(proxyStatus, .notRecording(.projectLimitReached))

        moduleStatus = .notRecording(.stopped)
        proxyStatus = .init(srStatus: moduleStatus)
        XCTAssertEqual(proxyStatus, .notRecording(.stopped))

        moduleStatus = .notRecording(.swiftUIPreviewContext)
        proxyStatus = .init(srStatus: moduleStatus)
        XCTAssertEqual(proxyStatus, .notRecording(.swiftUIPreviewContext))

        moduleStatus = .notRecording(.unsupportedPlatform)
        proxyStatus = .init(srStatus: moduleStatus)
        XCTAssertEqual(proxyStatus, .notRecording(.unsupportedPlatform))
    }

    func testStatusToModuleConversion() throws {
        /* From module to proxy */
        var proxyStatus: CiscoRUM.SessionReplayStatus = .recording
        var srStatus = proxyStatus.srStatus


        // Recording
        XCTAssertEqual(srStatus, .recording)


        // Not recording
        proxyStatus = .notRecording(.diskCacheCapacityOverreached)
        srStatus = proxyStatus.srStatus
        XCTAssertEqual(srStatus, .notRecording(.diskCacheCapacityOverreached))

        proxyStatus = .notRecording(.internalError)
        srStatus = proxyStatus.srStatus
        XCTAssertEqual(srStatus, .notRecording(.internalError))

        proxyStatus = .notRecording(.notStarted)
        srStatus = proxyStatus.srStatus
        XCTAssertEqual(srStatus, .notRecording(.notStarted))

        proxyStatus = .notRecording(.projectLimitReached)
        srStatus = proxyStatus.srStatus
        XCTAssertEqual(srStatus, .notRecording(.projectLimitReached))

        proxyStatus = .notRecording(.stopped)
        srStatus = proxyStatus.srStatus
        XCTAssertEqual(srStatus, .notRecording(.stopped))

        proxyStatus = .notRecording(.swiftUIPreviewContext)
        srStatus = proxyStatus.srStatus
        XCTAssertEqual(srStatus, .notRecording(.swiftUIPreviewContext))

        proxyStatus = .notRecording(.unsupportedPlatform)
        srStatus = proxyStatus.srStatus
        XCTAssertEqual(srStatus, .notRecording(.unsupportedPlatform))


        // Not recording (disabled from configuration)
        proxyStatus = .notRecording(.remotelyDisabled)
        srStatus = proxyStatus.srStatus
        XCTAssertEqual(srStatus, .notRecording(.notStarted))
    }
}
