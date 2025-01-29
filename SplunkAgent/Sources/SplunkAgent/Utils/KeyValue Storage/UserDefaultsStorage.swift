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

import Foundation
@_implementationOnly import SplunkLogger

/// The class implements a single persistent key-value store
/// using standard `UserDefaults` database services.
class UserDefaultsStorage: KeyValueStorage {

    // MARK: - Private

    private let userDefaults = UserDefaults.standard

    private let internalLogger = InternalLogger(configuration: .agent(category: "UserDefaults Storage"))


    // MARK: - Public

    /// Defines prefix for all entries managed by this instance.
    ///
    /// - Note: This prefix is used only internally in the preferences `.plist` file.
    public var keysPrefix: String? = "\(PackageIdentifier.default)."


    // MARK: - KeyValueStorage methods

    func insert(_ value: Codable, forKey key: String) throws {
        let storageKey = storageKey(for: key)

        // Verifies that there is no data for this key yet
        guard userDefaults.data(forKey: storageKey) == nil else {
            internalLogger.log(level: .info) {
                "Insert operation for key: \(storageKey) failed due to duplicate data present."
            }

            throw KeyValueStorageError.insertIntoExistingKey
        }

        // Save new record into storage
        guard let data = try? JSONEncoder().encode(value) else {
            internalLogger.log(level: .info) {
                "Insert operation for key: \(storageKey) failed while encoding data."
            }

            throw KeyValueStorageError.dataSerializationFailure
        }

        userDefaults.set(data, forKey: storageKey)
    }

    func read<T: Codable>(forKey key: String) throws -> T? {
        let storageKey = storageKey(for: key)

        // Reads corresponding data from storage
        guard let data = userDefaults.data(forKey: storageKey) else {
            return nil
        }

        // We try to decode data into target type.
        guard let value = try? JSONDecoder().decode(T.self, from: data) else {
            internalLogger.log(level: .info) {
                "Read operation for key: \(storageKey) failed while decoding data for type \(T.self)."
            }

            throw KeyValueStorageError.storedTypeMismatch
        }

        return value
    }

    func update(_ value: Codable, forKey key: String) throws {
        let storageKey = storageKey(for: key)

        // Save value data into storage
        guard let data = try? JSONEncoder().encode(value) else {
            internalLogger.log(level: .info) {
                "Update operation for key: \(storageKey) failed while encoding data."
            }

            throw KeyValueStorageError.dataSerializationFailure
        }

        userDefaults.set(data, forKey: storageKey)
    }

    func delete(forKey key: String) throws {
        let storageKey = storageKey(for: key)

        // Verifies that there is data for this key
        guard userDefaults.data(forKey: storageKey) != nil else {
            internalLogger.log(level: .info) {
                "Delete operation for key: \(storageKey) failed due to missing data."
            }

            throw KeyValueStorageError.noValueForKey
        }

        // Deletes record from storage
        userDefaults.removeObject(forKey: storageKey)
    }


    // MARK: - Private methods

    private func storageKey(for key: String) -> String {
        guard let keysPrefix else {
            return key
        }

        return keysPrefix + key
    }
}
