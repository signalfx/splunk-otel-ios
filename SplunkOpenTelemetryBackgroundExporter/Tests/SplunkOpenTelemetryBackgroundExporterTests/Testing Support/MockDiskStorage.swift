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

import CiscoDiskStorage
import Foundation

/// An in-memory fake implementation of `DiskStorage` for use in unit tests.
///
/// Stores key-value pairs in memory, allowing simulation of file operations,
/// deletions, and error behaviors.
final class MockDiskStorage: DiskStorage {

    var statistics: (any CiscoDiskStorage.Statistics)?
    private var storage: [String: Data] = [:]
    var files: [String: URL] = [:]
    var deletedKeys: [String] = []
    var shouldThrowOnFinalDestination = false
    var shouldThrowOnlist = false
    var shouldThrowOnInsert = false

    func insert(_ value: some Decodable & Encodable, forKey key: CiscoDiskStorage.KeyBuilder) throws {
        if shouldThrowOnInsert {
            throw NSError(domain: "MockDiskStorage", code: 1)
        }

        let keyStr = key.key
        let data = try JSONEncoder().encode(value)
        storage[keyStr] = data
    }

    func read<T: Decodable & Encodable>(forKey key: CiscoDiskStorage.KeyBuilder) throws -> T? {
        let keyStr = key.key

        guard let data = storage[keyStr]
        else {
            return nil
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    func update(_ value: some Decodable & Encodable, forKey key: CiscoDiskStorage.KeyBuilder) throws {
        try insert(value, forKey: key)
    }

    func list(forKey _: CiscoDiskStorage.KeyBuilder) throws -> [CiscoDiskStorage.ItemInfo] {
        if shouldThrowOnlist {
            throw NSError(domain: "MockDiskStorage", code: 1)
        }

        return []
    }

    func checkRules() throws {}

    func finalDestination(forKey key: KeyBuilder) throws -> URL {
        let keyString = key.key

        if shouldThrowOnFinalDestination {
            throw NSError(domain: "MockDiskStorage", code: 1)
        }

        return files[keyString] ?? URL(fileURLWithPath: "/notfound")
    }

    func delete(forKey key: KeyBuilder) {
        let keyString = key.key
        deletedKeys.append(keyString)
        // Remove from "disk"
        storage[keyString] = nil
        files[keyString] = nil
    }
}
