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

final class DefaultUserTests: XCTestCase {

    // MARK: - Tests

    func testBusinessLogic() throws {
        let testName = "defaultUserTest"
        let key = "userIdentifier"
        let keysPrefix = "\(PackageIdentifier.default).defaultUserTest."

        // Clean storage before test run
        UserDefaultsUtils.cleanItem(prefix: keysPrefix, key: key)


        // We need to test the class with separate storage
        let user = try DefaultUserTestBuilder.build(named: testName)


        // New identifier preparation
        let userIdentifier = user.userIdentifier
        XCTAssertNotNil(userIdentifier)

        // Check the returned value for its format
        try HexIDValidator.checkFormat(userIdentifier)


        // Use previously prepared identifiers
        //
        // NOTE:
        // This approach, in principle, simulates two application runs
        let anotherInstance = try DefaultUserTestBuilder.build(named: testName)
        let anotherIdentifier = anotherInstance.userIdentifier
        XCTAssertNotNil(anotherIdentifier)

        // The User between runs must be the same
        XCTAssertEqual(userIdentifier, anotherIdentifier)
    }

    func testConcurrentFirstReadsReturnOneStoredIdentifier() throws {
        let testName = "defaultUserConcurrencyTest"
        let key = "userIdentifier"
        let keysPrefix = "\(PackageIdentifier.default).\(testName)."
        let readerCount = 8
        let roundCount = 100

        let storage = UserDefaultsStorage()
        storage.keysPrefix = keysPrefix

        // Clean storage after test run, also when a `try` below throws
        defer {
            UserDefaultsUtils.cleanItem(prefix: keysPrefix, key: key)
        }

        for round in 0 ..< roundCount {
            // Each round starts with a fresh user and no stored identifier
            UserDefaultsUtils.cleanItem(prefix: keysPrefix, key: key)
            let user = try DefaultUserTestBuilder.build(named: testName)

            // All readers make the first read of the identifier at the same time
            let reads = ThreadSafeDictionary<Int, String>()
            DispatchQueue.concurrentPerform(iterations: readerCount) { reader in
                reads[reader] = user.userIdentifier
            }

            // Every reader gets the same identifier, and it is the stored one
            let identifiers = Set(reads.allValues())
            let storedIdentifier: String? = try storage.read(forKey: key)

            XCTAssertEqual(reads.count(), readerCount, "Round \(round)")
            XCTAssertEqual(identifiers.count, 1, "Round \(round): readers got \(identifiers.count) identifiers")
            XCTAssertEqual(storedIdentifier, identifiers.first, "Round \(round): stored identifier differs")
        }
    }

    func testReadInDefaultsObserverDuringFirstStore() throws {
        let testName = "defaultUserObserverTest"
        let key = "userIdentifier"
        let keysPrefix = "\(PackageIdentifier.default).\(testName)."

        // Start with a fresh user and no stored identifier
        UserDefaultsUtils.cleanItem(prefix: keysPrefix, key: key)
        let user = try DefaultUserTestBuilder.build(named: testName)

        // `UserDefaults` posts this notification synchronously on the thread that stores
        // the new identifier. App code can observe it and start a span there, which reads
        // the tracking mode and the identifier again.
        let readerThread = Thread.current
        let observedIdentifiers = ThreadSafeDictionary<Int, String>()

        let observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: nil
        ) { _ in
            // Other tests may write to `UserDefaults` on other threads
            if Thread.current == readerThread {
                _ = user.trackingMode
                observedIdentifiers[0] = user.userIdentifier
            }
        }

        defer {
            NotificationCenter.default.removeObserver(observer)
            UserDefaultsUtils.cleanItem(prefix: keysPrefix, key: key)
        }

        // The first read stores a new identifier, and the observer reads it again
        let identifier = user.userIdentifier

        XCTAssertEqual(observedIdentifiers[0], identifier)
    }
}
