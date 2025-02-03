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

final class UserDefaultsStorageCRUDTests: XCTestCase {

    // MARK: - Inline types

    /// Sample data for the purposes of this test
    struct SampleData: Codable, Equatable {
        var text: String
        var number: Int
    }


    // MARK: - Constants

    private let key = "testEntry"
    private let keysPrefix = "\(PackageIdentifier.default).keyValueTest."

    private let sampleData = SampleData(
        text: "Test data",
        number: 17
    )


    // MARK: - Private

    private var storage: UserDefaultsStorage!


    // MARK: - Tests lifecycle

    override func setUp() {
        super.setUp()

        // Clean storage before test run
        UserDefaultsUtils.cleanItem(prefix: keysPrefix, key: key)

        // Separated storage for this test
        storage = UserDefaultsStorage()
        storage.keysPrefix = keysPrefix
    }


    // MARK: - CRUD operations

    func testCreate() throws {
        // Sample data
        let value = sampleData


        // CREATE operation
        XCTAssertNoThrow(
            try storage.insert(value, forKey: key)
        )


        // We cannot perform another insert for same key
        let anotherValue = SampleData(text: "Another data", number: 55)

        XCTAssertThrowsError(
            try storage.insert(anotherValue, forKey: key)
        ) { error in
            XCTAssertEqual(error as? KeyValueStorageError, KeyValueStorageError.insertIntoExistingKey)
        }
    }

    func testRead() throws {
        // Insert some sample data
        let value = sampleData
        try? storage.insert(value, forKey: key)


        // READ operation
        var readValue: SampleData?

        XCTAssertNoThrow(
            readValue = try? storage.read(forKey: key)
        )
        XCTAssertNotNil(readValue)

        if let readValue {
            XCTAssertEqual(readValue, value)
        }


        // The operation should fail if the expected data type
        // differs from the type of stored data.
        var number: Double?

        XCTAssertThrowsError(
            number = try storage.read(forKey: key)
        ) { error in
            XCTAssertEqual(error as? KeyValueStorageError, KeyValueStorageError.storedTypeMismatch)
        }
        XCTAssertNil(number)
    }

    func testUpdate() throws {
        // Insert some sample data
        let value = SampleData(text: "Test data", number: 17)
        try? storage.insert(value, forKey: key)


        // UPDATE operation
        let newValue = SampleData(text: "Changed data", number: 100)
        XCTAssertNoThrow(
            try storage.update(newValue, forKey: key)
        )

        var updatedValue: SampleData?

        XCTAssertNoThrow(
            try updatedValue = storage.read(forKey: key)
        )

        if let updatedValue {
            XCTAssertEqual(updatedValue, newValue)
        }
    }

    func testDelete() throws {
        // Insert some sample data
        let value = SampleData(text: "Test data", number: 17)
        try? storage.insert(value, forKey: key)


        // DELETE operation
        XCTAssertNoThrow(
            try storage.delete(forKey: key)
        )

        var postDeletedValue: SampleData?

        XCTAssertNoThrow(
            postDeletedValue = try storage.read(forKey: key)
        )
        XCTAssertNil(postDeletedValue)


        // Attempt to delete data for non-existing key should fail
        XCTAssertThrowsError(
            try storage.delete(forKey: "someUniqueKey-OkCqw4S")
        ) { error in
            XCTAssertEqual(error as? KeyValueStorageError, KeyValueStorageError.noValueForKey)
        }
    }


    // MARK: - Non-encodable error handling

    func testNonEncodableCreate() throws {
        // Sample data
        let value: Double = .nan

        // Attempt to insert model with invalid/non-serializable data should fail
        XCTAssertThrowsError(
            try storage.insert(value, forKey: key)
        ) { error in
            XCTAssertEqual(error as? KeyValueStorageError, KeyValueStorageError.dataSerializationFailure)
        }
    }

    func testNonEncodableUpdate() throws {
        // Sample data
        let value: Double = .nan

        // Attempt to update model with invalid/non-serializable data should fail
        XCTAssertThrowsError(
            try storage.update(value, forKey: key)
        ) { error in
            XCTAssertEqual(error as? KeyValueStorageError, KeyValueStorageError.dataSerializationFailure)
        }
    }
}
