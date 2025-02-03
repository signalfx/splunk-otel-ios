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

final class SessionReplayAPI10ExtensionsTests: XCTestCase {

    // MARK: - Sensitivity extension

    func testUIViewSensitivityExtension() throws {
        // NOTE:
        // This flow is not split into multiple tests as we need to avoid interference caused
        // by forced access via a singleton instance in the agent and its equivalent
        // in the Session Replay module.

        // Agent install with initialized Session Replay module (by default)
        let configuration = try ConfigurationTestBuilder.buildDefault()
        let agent = SplunkRum.install(with: configuration)

        // Stop recording immediately (we don't need it)
        agent.sessionReplay.stop()


        /* Operational Proxy (by default) */
        let view = UIView()
        view.srSensitive = true
        XCTAssertTrue(try XCTUnwrap(agent.sessionReplay.sensitivity[view]))

        view.srSensitive = false
        XCTAssertFalse(try XCTUnwrap(agent.sessionReplay.sensitivity[view]))

        view.srSensitive = nil
        XCTAssertFalse(try XCTUnwrap(agent.sessionReplay.sensitivity[view]))

        let isSensitive = agent.sessionReplay.sensitivity[view]
        XCTAssertNotNil(isSensitive)

        _ = view.srSensitive


        /* Non-Operational proxy */
        agent.sessionReplayProxy = SessionReplayTestBuilder.buildNonOperational()

        let secondView = UIView()
        secondView.srSensitive = true
        XCTAssertNil(agent.sessionReplay.sensitivity[secondView])

        secondView.srSensitive = false
        XCTAssertNil(agent.sessionReplay.sensitivity[secondView])

        secondView.srSensitive = nil
        XCTAssertNil(agent.sessionReplay.sensitivity[secondView])

        _ = secondView.srSensitive
    }
}
