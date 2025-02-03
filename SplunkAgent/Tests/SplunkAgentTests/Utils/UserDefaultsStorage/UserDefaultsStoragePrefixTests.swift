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

final class UserDefaultsStoragePrefixTests: XCTestCase {

    // MARK: - Tests

    func testDefaultKeysPrefix() throws {
        let defaultKeysPrefix = "com.splunk.rum."

        // Default prefix value
        let storage = UserDefaultsStorage()
        let keysPrefix = storage.keysPrefix
        XCTAssertNotNil(keysPrefix)
        XCTAssertEqual(keysPrefix, defaultKeysPrefix)

        // Prefix update
        let newKeysPrefix = "com.sample."
        storage.keysPrefix = newKeysPrefix

        let updatedKeysPrefix = storage.keysPrefix
        XCTAssertEqual(updatedKeysPrefix, newKeysPrefix)
    }

    func testClearPrefix() throws {
        let key = "testClearPrefix"
        let value = "Test data"

        // Clean storage before test run
        let prefix = UserDefaultsStorage().keysPrefix
        UserDefaultsUtils.cleanItem(prefix: prefix, key: key)
        UserDefaultsUtils.cleanItem(prefix: nil, key: key)


        // Storage with clear prefix
        let nilPrefixStorage = UserDefaultsStorage()
        nilPrefixStorage.keysPrefix = nil
        XCTAssertNil(nilPrefixStorage.keysPrefix)

        // Storage with prefix (default)
        let prefixedStorage = UserDefaultsStorage()
        XCTAssertNotNil(prefixedStorage.keysPrefix)

        // Write test record into non-prefixed and prefixed storage
        try? nilPrefixStorage.insert(value, forKey: key)
        try? prefixedStorage.insert("anotherData", forKey: key)


        // Try to read the record for non-existing key
        let nilText: String? = try? nilPrefixStorage.read(forKey: "WdiZZ9")
        XCTAssertNil(nilText)

        // Try to read data for an existing keys
        let readText: String? = try? nilPrefixStorage.read(forKey: key)
        XCTAssertNotNil(readText)
        XCTAssertEqual(readText, value)

        // Data from storages should be different
        let nilPrefixedData: String? = try? nilPrefixStorage.read(forKey: key)
        let prefixedData: String? = try? prefixedStorage.read(forKey: key)
        XCTAssertNotEqual(nilPrefixedData, prefixedData)
    }

    func testKeysPrefix() throws {
        let key = "captainName"

        let firstPrefix = "\(PackageIdentifier.default).firstStorageTest."
        let secondPrefix = "\(PackageIdentifier.default).secondStorageTest."

        // Clean storage before test run
        UserDefaultsUtils.cleanItem(prefix: firstPrefix, key: key)
        UserDefaultsUtils.cleanItem(prefix: secondPrefix, key: key)


        // Storages separated by `keyPrefix`
        let firstStorage = UserDefaultsStorage()
        firstStorage.keysPrefix = firstPrefix

        let secondStorage = UserDefaultsStorage()
        secondStorage.keysPrefix = secondPrefix

        // Save some data
        let firstValue = "James Tiberius Kirk"
        try? firstStorage.insert(firstValue, forKey: key)

        let secondValue = "Jonathan Archer"
        try? secondStorage.insert(secondValue, forKey: key)


        // Values with the same *key* should be separated
        // by `keyPrefix` into separate items
        let firstReadName: String? = try? firstStorage.read(forKey: key)
        let secondReadName: String? = try? secondStorage.read(forKey: key)
        XCTAssertEqual(firstValue, firstReadName)
        XCTAssertEqual(secondValue, secondReadName)

        XCTAssertNotEqual(firstReadName, secondReadName)
    }
}
