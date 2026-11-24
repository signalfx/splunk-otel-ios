//
/*
Copyright 2026 Splunk Inc.

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
import SplunkCommon

@testable import SplunkAgent

/// A storage whose reads of the held session starts throw, as a read of an unreadable file does.
///
/// Other keys, and saves of the held session starts, pass through to the wrapped storage.
final class FailingHeldStartReadStorage: KeyValueStorage {

    // MARK: - Read error

    /// The error thrown by reads of the held session starts.
    struct ReadError: Error {}


    // MARK: - Private

    private let storage: KeyValueStorage


    // MARK: - Initialization

    init(wrapping storage: KeyValueStorage) {
        self.storage = storage
    }


    // MARK: - CRUD operations

    func insert(_ value: Codable, forKey key: String) throws {
        try storage.insert(value, forKey: key)
    }

    func read<T: Codable>(forKey key: String) throws -> T? {
        if key == HeldSessionStartStore.storageKey {
            throw ReadError()
        }

        return try storage.read(forKey: key)
    }

    func update(_ value: Codable, forKey key: String) throws {
        try storage.update(value, forKey: key)
    }

    func delete(forKey key: String) throws {
        try storage.delete(forKey: key)
    }
}
