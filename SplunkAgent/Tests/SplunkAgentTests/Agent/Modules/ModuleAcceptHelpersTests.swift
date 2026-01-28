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

import SplunkCommon
import XCTest
@testable import SplunkAgent

final class ModuleAcceptHelpersTests: XCTestCase {

    // MARK: - Private

    private var sessionReplay: (any Module)?


    // MARK: - Tests lifecycle

    override func setUp() {
        super.setUp()

        // Assign test modules
        sessionReplay = SessionReplayTestModule()
    }

    override func tearDown() {
        sessionReplay = nil

        super.tearDown()
    }


    // MARK: - Module helpers

    func testAcceptsConfiguration() throws {
        let sessionReplay = try XCTUnwrap(sessionReplay)

        let configuration = SessionReplayTestConfiguration()
        let configurationType = type(of: configuration)

        let wrongConfiguration = CrashReportsTestConfiguration()
        let wrongConfigurationType = type(of: wrongConfiguration)

        let accepts = type(of: sessionReplay).acceptsConfiguration(type: configurationType)
        let notAccepts = type(of: sessionReplay).acceptsConfiguration(type: wrongConfigurationType)

        XCTAssertTrue(accepts)
        XCTAssertFalse(notAccepts)
    }

    func testAcceptsRemoteConfiguration() throws {
        let sessionReplay = try XCTUnwrap(sessionReplay)

        // Load raw configuration mock
        let rawConfiguration = try RawMockDataBuilder.build(mockFile: .remoteConfiguration)

        // Session Replay test module
        let remoteConfiguration = SessionReplayTestRemoteConfiguration(from: rawConfiguration)
        let configuration = try XCTUnwrap(remoteConfiguration)
        let configurationType = type(of: configuration)

        // Crash Reports test module
        let wrongRemoteConfiguration = CrashReportsTestRemoteConfiguration(from: rawConfiguration)
        let wrongConfiguration = try XCTUnwrap(wrongRemoteConfiguration)
        let wrongConfigurationType = type(of: wrongConfiguration)

        let accepts = type(of: sessionReplay).acceptsRemoteConfiguration(type: configurationType)
        let notAccepts = type(of: sessionReplay).acceptsRemoteConfiguration(type: wrongConfigurationType)

        XCTAssertTrue(accepts)
        XCTAssertFalse(notAccepts)
    }

    func testAcceptsMetadata() throws {
        let sessionReplay = try XCTUnwrap(sessionReplay)

        let metadata = SessionReplayTestMetadata(id: String.uniqueIdentifier())
        let metadataType = type(of: metadata)

        let wrongMetadata = CrashReportsTestMetadata(id: String.uniqueIdentifier())
        let wrongMetadataType = type(of: wrongMetadata)

        let accepts = type(of: sessionReplay).acceptsMetadata(type: metadataType)
        let notAccepts = type(of: sessionReplay).acceptsMetadata(type: wrongMetadataType)

        XCTAssertTrue(accepts)
        XCTAssertFalse(notAccepts)
    }
}
