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

import XCTest

@testable import SplunkAgent

final class AppVersionTrackerTests: XCTestCase {

    private var storage: KeyValueStorage!


    // MARK: - XCTestCase

    override func setUp() {
        super.setUp()

        storage = UserDefaultsStorageTestBuilder.buildCleanStorage(named: "appVersionTrackerTests")
        clearStorage()
    }

    override func tearDown() {
        clearStorage()
        storage = nil

        super.tearDown()
    }


    // MARK: - Tests

    func testFirstInstallationHasNoPreviousVersion() throws {
        XCTAssertNil(try tracker(for: "5.2.0").previousVersion)
    }

    func testUpgradeRecordsTheInstalledVersionAsPrevious() throws {
        _ = try tracker(for: "5.1.3")

        let upgraded = try tracker(for: "5.2.0")

        XCTAssertEqual(upgraded.previousVersion, "5.1.3")
    }

    func testRelaunchKeepsThePreviousVersion() throws {
        _ = try tracker(for: "5.1.3")
        _ = try tracker(for: "5.2.0")

        let relaunched = try tracker(for: "5.2.0")

        XCTAssertEqual(relaunched.previousVersion, "5.1.3")
    }

    func testSubsequentUpgradeReplacesThePreviousVersion() throws {
        _ = try tracker(for: "5.1.3")
        _ = try tracker(for: "5.2.0")

        let subsequentUpgrade = try tracker(for: "5.3.0")

        XCTAssertEqual(subsequentUpgrade.previousVersion, "5.2.0")
    }

    func testDowngradeRecordsTheVersionBeingDowngradedFrom() throws {
        _ = try tracker(for: "5.1.3")
        _ = try tracker(for: "5.2.0")
        _ = try tracker(for: "5.3.0")

        let downgrade = try tracker(for: "5.2.0")

        XCTAssertEqual(downgrade.previousVersion, "5.3.0")
    }

    func testCleanReinstallHasNoPreviousVersion() throws {
        _ = try tracker(for: "5.2.0")
        let installationIdBeforeReinstall = try XCTUnwrap(
            AppInstallationStorage.identifier(using: storage)
        )

        clearStorage()

        let reinstalled = try tracker(for: "5.3.0")
        let installationIdAfterReinstall = try XCTUnwrap(
            AppInstallationStorage.identifier(using: storage)
        )

        XCTAssertNil(reinstalled.previousVersion)
        XCTAssertNotEqual(installationIdAfterReinstall, installationIdBeforeReinstall)
    }

    func testEmptyCurrentVersionDoesNotCreatePreviousVersion() throws {
        XCTAssertNil(try tracker(for: "").previousVersion)

        let firstVersion = try tracker(for: "5.2.0")

        XCTAssertNil(firstVersion.previousVersion)
    }


    // MARK: - Private methods

    private func tracker(for version: String) throws -> AppVersionTracker {
        AppVersionTracker.record(currentVersion: version, storage: try XCTUnwrap(storage))
        return AppVersionTracker(currentVersion: version, storage: try XCTUnwrap(storage))
    }

    private func clearStorage() {
        try? storage?.delete(forKey: AppInstallationStorage.installationIdKey)
        try? storage?.delete(forKey: AppVersionTracker.storageKey)
    }
}
