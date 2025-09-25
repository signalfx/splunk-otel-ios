//
/*
Copyright 2025 Splunk Inc.

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

import CiscoSessionReplay
import XCTest

@testable import SplunkAgent

final class SessionReplayAPI10TypeConversionsTests: XCTestCase {

    // MARK: - Rendering mode

    func testRenderingModesToProxyConversion() throws {
        /* From module to proxy */
        var moduleRenderingMode: SplunkSessionReplayRenderingMode = .default
        var proxyRenderingMode: SplunkAgent.RenderingMode = .default

        // Test for all possible options
        proxyRenderingMode = .init(with: moduleRenderingMode)
        XCTAssertEqual(proxyRenderingMode, .default)

        moduleRenderingMode = .native
        proxyRenderingMode = .init(with: moduleRenderingMode)
        XCTAssertEqual(proxyRenderingMode, .native)

        moduleRenderingMode = .wireframe
        proxyRenderingMode = .init(with: moduleRenderingMode)
        XCTAssertEqual(proxyRenderingMode, .wireframeOnly)
    }

    func testRenderingModesToModuleConversion() throws {
        /* From proxy to module */
        var proxyRenderingMode: SplunkAgent.RenderingMode = .default
        var srRenderingMode = proxyRenderingMode.srRenderingMode
        XCTAssertEqual(srRenderingMode, .default)

        proxyRenderingMode = .native
        srRenderingMode = proxyRenderingMode.srRenderingMode
        XCTAssertEqual(srRenderingMode, .native)

        proxyRenderingMode = .wireframeOnly
        srRenderingMode = proxyRenderingMode.srRenderingMode
        XCTAssertEqual(srRenderingMode, .wireframe)
    }


    // MARK: - Status

    func testStatusToProxyConversion() throws {
        /* From module to proxy */
        var moduleStatus: SplunkSessionReplayStatus = .recording
        var proxyStatus: SplunkAgent.SessionReplayStatus = .recording


        // Recording
        proxyStatus = .init(srStatus: moduleStatus)
        XCTAssertEqual(proxyStatus, .recording)


        // Not recording
        moduleStatus = .notRecording(.diskCacheCapacityOverreached)
        proxyStatus = .init(srStatus: moduleStatus)
        XCTAssertEqual(proxyStatus, .notRecording(.storageLimitReached))

        moduleStatus = .notRecording(.internalError)
        proxyStatus = .init(srStatus: moduleStatus)
        XCTAssertEqual(proxyStatus, .notRecording(.internalError))

        moduleStatus = .notRecording(.notStarted)
        proxyStatus = .init(srStatus: moduleStatus)
        XCTAssertEqual(proxyStatus, .notRecording(.notStarted))

        moduleStatus = .notRecording(.stopped)
        proxyStatus = .init(srStatus: moduleStatus)
        XCTAssertEqual(proxyStatus, .notRecording(.stopped))

        moduleStatus = .notRecording(.internalError)
        proxyStatus = .init(srStatus: moduleStatus)
        XCTAssertEqual(proxyStatus, .notRecording(.internalError))

        moduleStatus = .notRecording(.swiftUIPreviewContext)
        proxyStatus = .init(srStatus: moduleStatus)
        XCTAssertEqual(proxyStatus, .notRecording(.swiftUIPreviewContext))

        moduleStatus = .notRecording(.unsupportedPlatform)
        proxyStatus = .init(srStatus: moduleStatus)
        XCTAssertEqual(proxyStatus, .notRecording(.unsupportedPlatform))

        moduleStatus = .notRecording(.diskCacheCapacityOverreached)
        proxyStatus = .init(srStatus: moduleStatus)
        XCTAssertEqual(proxyStatus, .notRecording(.storageLimitReached))
    }

    func testStatusToModuleConversion() throws {
        /* From proxy to module */
        var proxyStatus: SplunkAgent.SessionReplayStatus = .recording
        var srStatus = proxyStatus.srStatus


        // Recording
        XCTAssertEqual(srStatus, .recording)


        // Not recording
        proxyStatus = .notRecording(.storageLimitReached)
        srStatus = proxyStatus.srStatus
        XCTAssertEqual(srStatus, .notRecording(.diskCacheCapacityOverreached))

        proxyStatus = .notRecording(.internalError)
        srStatus = proxyStatus.srStatus
        XCTAssertEqual(srStatus, .notRecording(.internalError))

        proxyStatus = .notRecording(.notStarted)
        srStatus = proxyStatus.srStatus
        XCTAssertEqual(srStatus, .notRecording(.notStarted))

        proxyStatus = .notRecording(.stopped)
        srStatus = proxyStatus.srStatus
        XCTAssertEqual(srStatus, .notRecording(.stopped))

        proxyStatus = .notRecording(.swiftUIPreviewContext)
        srStatus = proxyStatus.srStatus
        XCTAssertEqual(srStatus, .notRecording(.swiftUIPreviewContext))

        proxyStatus = .notRecording(.unsupportedPlatform)
        srStatus = proxyStatus.srStatus
        XCTAssertEqual(srStatus, .notRecording(.unsupportedPlatform))
    }


    // MARK: - Masks type

    func testMaskTypeToProxyConversion() throws {
        /* From module to proxy */
        var moduleMaskType: SplunkSessionReplayMaskType = .covering
        var proxyMaskType: SplunkAgent.MaskElement.MaskType = .covering

        // Covering
        proxyMaskType = .init(from: moduleMaskType)
        XCTAssertEqual(proxyMaskType, .covering)

        // Erasing
        moduleMaskType = .erasing
        proxyMaskType = .init(from: moduleMaskType)
        XCTAssertEqual(proxyMaskType, .erasing)
    }
}
