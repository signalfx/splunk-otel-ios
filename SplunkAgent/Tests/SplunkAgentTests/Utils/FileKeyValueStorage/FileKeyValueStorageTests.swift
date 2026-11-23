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

import Foundation
import XCTest

@testable import SplunkAgent

final class FileKeyValueStorageTests: XCTestCase {

    // MARK: - Private

    /// A directory of its own for each test, as XCTest creates a new instance for every test.
    private let directory = makeTemporaryDirectory()


    // MARK: - Setup

    override func setUp() {
        super.setUp()

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)

        super.tearDown()
    }


    // MARK: - CRUD

    func testUpdateCreatesTheDirectoryAndReadReturnsTheValue() throws {
        let storage = FileKeyValueStorage(directory: directory.appendingPathComponent("nested", isDirectory: true))

        try storage.update(["a", "b"], forKey: "list")

        let value: [String]? = try storage.read(forKey: "list")
        XCTAssertEqual(value, ["a", "b"])
    }

    func testValueIsReadByAnotherInstanceInTheSameDirectory() throws {
        try FileKeyValueStorage(directory: directory).update(42, forKey: "number")

        let value: Int? = try FileKeyValueStorage(directory: directory).read(forKey: "number")
        XCTAssertEqual(value, 42)
    }

    func testReadOfMissingKeyReturnsNil() throws {
        let value: String? = try FileKeyValueStorage(directory: directory).read(forKey: "missing")

        XCTAssertNil(value)
    }

    func testReadOfOtherTypeThrows() throws {
        let storage = FileKeyValueStorage(directory: directory)
        try storage.update("text", forKey: "key")

        XCTAssertThrowsError(try storage.read(forKey: "key") as [Int]?)
    }

    func testInsertIntoExistingKeyThrows() throws {
        let storage = FileKeyValueStorage(directory: directory)
        try storage.insert(1, forKey: "key")

        XCTAssertThrowsError(try storage.insert(2, forKey: "key"))

        let value: Int? = try storage.read(forKey: "key")
        XCTAssertEqual(value, 1)
    }

    func testDeleteRemovesTheValue() throws {
        let storage = FileKeyValueStorage(directory: directory)
        try storage.update(1, forKey: "key")

        try storage.delete(forKey: "key")

        let value: Int? = try storage.read(forKey: "key")
        XCTAssertNil(value)
        XCTAssertThrowsError(try storage.delete(forKey: "key"))
    }


    // MARK: - Backup

    func testCreatedDirectoryIsExcludedFromBackup() throws {
        let storeDirectory = directory.appendingPathComponent("store", isDirectory: true)

        try FileKeyValueStorage(directory: storeDirectory).update(1, forKey: "key")

        let resourceValues = try storeDirectory.resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertEqual(resourceValues.isExcludedFromBackup, true)
    }


    // MARK: - Helpers

    private static func makeTemporaryDirectory() -> URL {
        let name = "FileKeyValueStorageTests-\(UUID().uuidString)"

        return FileManager.default.temporaryDirectory.appendingPathComponent(name, isDirectory: true)
    }
}
