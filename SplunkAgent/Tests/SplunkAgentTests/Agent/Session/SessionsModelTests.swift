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

final class SessionsModelTests: XCTestCase {

    // MARK: - Private

    private let storageKey = UserDefaultsStorageTestBuilder.defaultKey


    // MARK: - Basic logic

    func testInitialization() throws {
        // Default instance
        let defaultModel = SessionsModel()
        XCTAssertNotNil(defaultModel)

        // Customized instance
        let name = "sessionsTest"
        let storage = UserDefaultsStorage()

        let customizedModel = SessionsModel(named: name, storage: storage)
        XCTAssertNotNil(customizedModel)
        XCTAssertEqual(customizedModel.storageKey, name)

        let assignedStorage = customizedModel.storage as? UserDefaultsStorage
        XCTAssertTrue(assignedStorage === storage)
    }

    func testBasicLogic() throws {
        // We need to test the class with separate storage
        let storage = UserDefaultsStorageTestBuilder.buildCleanStorage(named: "sessionModelTest")
        let sessionModel = SessionsModel(storage: storage)


        // After initialization, model should be empty
        let sessions = sessionModel.sessions
        XCTAssertTrue(sessions.isEmpty)
    }


    // MARK: - Storage management

    func testStorageManagement() throws {
        let testName = "storageManagementTest"
        let storage = UserDefaultsStorageTestBuilder.buildCleanStorage(named: testName)
        let sessionModel = SessionsModel(storage: storage)

        // We need add some data
        let sampleData = buildSampleData()
        sessionModel.sessions.append(contentsOf: sampleData)


        // Save data in storage
        sessionModel.sync()

        let keysPrefix = "\(PackageIdentifier.default).\(testName)."
        let matchedSessions = PersistentSessionsValidator.findPersistentMatches(
            with: sampleData,
            keysPrefix: keysPrefix,
            storageKey: storageKey
        )
        XCTAssertEqual(sampleData, matchedSessions)


        // Test `purge()` method
        // 96 session items should left (according to sample data)
        sessionModel.purge()
        XCTAssertEqual(sessionModel.sessions.count, 96)


        // Save new state into storage
        sessionModel.sync()

        let remainingSessions = PersistentSessionsValidator.findPersistentMatches(
            with: sampleData,
            keysPrefix: keysPrefix,
            storageKey: storageKey
        )
        XCTAssertEqual(sessionModel.sessions, remainingSessions)
    }


    // MARK: - Storage utils

    func testStorageUtils() throws {
        let testName = "storageUtilsTest"
        let storage = UserDefaultsStorageTestBuilder.buildCleanStorage(named: testName)
        let sessionModel = SessionsModel(storage: storage)

        // We need to add some data
        let sampleData = buildSampleData()
        sessionModel.sessions.append(contentsOf: sampleData)

        let oldestItem = sessionModel.sessions[0]


        // Delete items that exceed the allowed order
        // 120 session items should left
        sessionModel.delete(exceedingOrder: 120)
        XCTAssertEqual(sessionModel.sessions.count, 120)

        // Delete all outdated sessions
        let oneWeekInterval: TimeInterval = 7 * 24 * 60 * 60
        let weekAgo = Date() - oneWeekInterval
        sessionModel.delete(before: weekAgo)

        // 14 session items should left (according to sample data)
        XCTAssertEqual(sessionModel.sessions.count, 14)

        // Older items should be deleted first
        let containedItem = sessionModel.sessions.first(where: { sessionItem in
            sessionItem == oldestItem
        })
        XCTAssertNil(containedItem)

        let containsOldItems = sessionModel.sessions.filter { sessionItem in
            sessionItem.start < weekAgo
        }.count > 0
        XCTAssertFalse(containsOldItems)
    }


    // MARK: - Sample data

    func buildSampleData() -> [SessionItem] {
        // 1.5 Months ago
        let startAgoInterval: TimeInterval = 4_017_600
        // 7 Hours
        let stepInterval: TimeInterval = 25200


        var sessions = [SessionItem]()

        // Creates sample data (150 entries with 7 hour gap)
        for index in 0 ..< 150 {
            let interval = startAgoInterval - (Double(index) * stepInterval)
            let startDate = Date() - interval

            let sessionItem = SessionItem(
                id: String.uniqueIdentifier(),
                start: startDate,
                closed: index < 149
            )

            sessions.append(sessionItem)
        }

        return sessions
    }
}
