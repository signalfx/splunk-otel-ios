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

final class DefaultUserTests: XCTestCase {

    // MARK: - Tests

    func testBusinessLogic() throws {
        let key = "userIdentifier"
        let keysPrefix = "\(PackageIdentifier.default).defaultUserTest."

        // Clean storage before test run
        UserDefaultsUtils.cleanItem(prefix: keysPrefix, key: key)


        // We need to test the class with separate storage
        let storage = UserDefaultsStorage()
        storage.keysPrefix = keysPrefix

        let user = DefaultUser(storage: storage)


        // New identifier preparation
        let userIdentifier = user.userIdentifier
        XCTAssertNotNil(userIdentifier)

        // Check the returned value for its format
        try NanoIDValidator.checkFormat(userIdentifier)


        // Use previously prepared identifiers
        //
        // NOTE:
        // This approach, in principle, simulates two application runs
        let anotherInstance = DefaultUser(storage: storage)
        let anotherIdentifier = anotherInstance.userIdentifier
        XCTAssertNotNil(anotherIdentifier)

        // The User between runs must be the same
        XCTAssertEqual(userIdentifier, anotherIdentifier)
    }

    func testProperties() throws {
        let storage = UserDefaultsStorage()
        let user = DefaultUser(storage: storage)


        // Properties (READ)
        let userStorage = user.storage as? UserDefaultsStorage
        XCTAssertNotNil(userStorage)
        XCTAssertTrue(storage === userStorage)


        // Properties (WRITE)
        let anotherKeysPrefix = "com.sample."
        let anotherStorage = UserDefaultsStorage()
        anotherStorage.keysPrefix = anotherKeysPrefix

        user.storage = anotherStorage
        XCTAssertNotNil(user.storage)

        let assignedKeysPrefix = (user.storage as? UserDefaultsStorage)?.keysPrefix
        XCTAssertNotNil(assignedKeysPrefix)
        XCTAssertEqual(assignedKeysPrefix, anotherKeysPrefix)
    }
}
