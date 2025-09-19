//
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
import CiscoDiskStorage

/// A simple test implementation of a key builder,
/// mimicking CiscoDiskStorage.KeyBuilder for use in unit tests.
///
/// This builder helps compose hierarchical keys for identifying
/// files or objects in the fake disk storage.
final class TestKeyBuilder {

    /// The unique string representing this key.
    let key: String
    /// Optional parent key builder for building key hierarchies.
    let parrentKeyBuilder: TestKeyBuilder?
    /// Content type, not used in tests.
    let contentType: Any?

    /// Initializes a new test key builder.
    ///
    /// - Parameters:
    ///   - key: The string key.
    ///   - parrentKeyBuilder: The (optional) parent key.
    ///   - contentType: The (optional) content type.
    init(_ key: String, parrentKeyBuilder: TestKeyBuilder? = nil, contentType: Any? = nil) {
        self.key = key
        self.parrentKeyBuilder = parrentKeyBuilder
        self.contentType = contentType
    }

    /// Returns a new key builder by appending a new key component.
    ///
    /// - Parameters:
    ///   - key: The string to append.
    ///   - contentType: Optional content type.
    /// - Returns: A new TestKeyBuilder with the appended key.
    func append(_ key: String, contentType: Any? = nil) -> TestKeyBuilder {
        TestKeyBuilder(key, parrentKeyBuilder: self, contentType: contentType)
    }

    /// A static key builder for "uploadFiles".
    static let uploadsKey = TestKeyBuilder("uploadFiles")
}

/// An in-memory fake implementation of `DiskStorage` for use in unit tests.
///
/// Stores key-value pairs in memory, allowing simulation of file operations,
/// deletions, and error behaviors.
final class FakeDiskStorage: DiskStorage {

    /// Test statistics, not used in fake implementation.
    var statistics: (any CiscoDiskStorage.Statistics)?

    /// Internal storage for encoded values (simulating disk).
    private var storage: [String: Data] = [:]

    /// Simulated file URLs by key string.
    var files: [String: URL] = [:]

    /// List of deleted key strings, for verifying deletions in tests.
    var deletedKeys: [String] = []

    /// If true, `finalDestination(forKey:)` will throw an error to simulate disk failure.
    var shouldThrowOnFinalDestination = false

    /// Converts any supported key type to a string for lookup.
    ///
    /// - Parameter key: The key as TestKeyBuilder, CiscoDiskStorage.KeyBuilder, or String.
    /// - Returns: The string representation of the key.
    func keyString(for key: Any) -> String {
        if let testKey = key as? TestKeyBuilder {
            return testKey.key
        } else if let prodKey = key as? CiscoDiskStorage.KeyBuilder {
            return prodKey.key
        } else if let str = key as? String {
            return str
        } else {
            return String(describing: key)
        }
    }

    /// Inserts a codable value into the fake storage for the given key.
    ///
    /// - Parameters:
    ///   - value: The value to store.
    ///   - key: The storage key.
    func insert<T>(_ value: T, forKey key: CiscoDiskStorage.KeyBuilder) throws where T : Decodable, T : Encodable {
        let keyStr = keyString(for: key)
        let data = try JSONEncoder().encode(value)
        storage[keyStr] = data
    }

    /// Reads a codable value from the fake storage for the given key.
    ///
    /// - Parameter key: The storage key.
    /// - Returns: The decoded value if found, otherwise `nil`.
    func read<T>(forKey key: CiscoDiskStorage.KeyBuilder) throws -> T? where T : Decodable, T : Encodable {
        let keyStr = keyString(for: key)
        guard let data = storage[keyStr] else { return nil }
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Updates a value by replacing it in storage.
    ///
    /// - Parameters:
    ///   - value: The new value.
    ///   - key: The storage key.
    func update<T>(_ value: T, forKey key: CiscoDiskStorage.KeyBuilder) throws where T : Decodable, T : Encodable {
        try insert(value, forKey: key)
    }

    /// Returns an empty list; not used in tests.
    func list(forKey key: CiscoDiskStorage.KeyBuilder) throws -> [CiscoDiskStorage.ItemInfo] {
        []
    }

    /// No-op; not used in test storage.
    func checkRules() throws {}

    /// Returns a file URL for the given key, or a dummy non-existent URL.
    /// Optionally throws for error simulation.
    ///
    /// - Parameter key: The key for which to retrieve the file URL.
    /// - Returns: The file URL associated with the key, or "/notfound".
    func finalDestination(forKey key: KeyBuilder) throws -> URL {
        // For test, we accept either TestKeyBuilder or CiscoDiskStorage.KeyBuilder
        let keyString = keyString(for: key)
        if shouldThrowOnFinalDestination { throw NSError(domain: "FakeDiskStorage", code: 1) }
        return files[keyString] ?? URL(fileURLWithPath: "/notfound")
    }

    /// Deletes the value and file for the given key, records the deleted key for test assertions.
    ///
    /// - Parameter key: The key to delete.
    func delete(forKey key: KeyBuilder) throws {
        let keyString = keyString(for: key)
        deletedKeys.append(keyString)
        // Remove from "disk"
        storage[keyString] = nil
        files[keyString] = nil
    }
}
