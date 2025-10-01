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

/// Defines general errors for data operations that can occur in this type of storage.
enum KeyValueStorageError: Error {

    /// The type of stored data does not match the expected type.
    case storedTypeMismatch

    /// There was no value for the requested key.
    case noValueForKey

    /// Attempt to insert a value into an existing key.
    case insertIntoExistingKey

    /// Failure to serialize a value for store purposes.
    case dataSerializationFailure
}


/// Defines the basic methods for data management in key-value storage.
protocol KeyValueStorage {

    // MARK: - CRUD operations

    /// Inserts data into the storage for the specified key.
    ///
    /// The stored data must conform to the codable protocol. Therefore,
    /// keeping any data in any internal structure is possible.
    ///
    /// - Parameters:
    ///   - value: General encodable data for storing.
    ///   - key: An access key in the storage.
    ///
    /// - Throws: `KeyValueStorageError.insertIntoExistingKey` if an insert operation
    ///             is performed on an existing key.
    /// - Throws: `KeyValueStorageError.dataSerializationFailure` if the attempt to serialize
    ///              a value for storage purposes fails.
    func insert(_ value: Codable, forKey key: String) throws

    /// Reads data for given key.
    ///
    /// - Parameter key: An access key in the storage.
    ///
    /// - Returns: Previously stored data or `nil`.
    ///
    /// - Throws: `KeyValueStorageError.storedTypeMismatch` if the type of stored data
    ///             does not match the expected type.
    func read<T: Codable>(forKey key: String) throws -> T?

    /// Updates data for given key.
    ///
    /// If no data is stored for this key, a new record will be created.
    ///
    /// - Parameters:
    ///   - value: New version of stored data.
    ///   - key: An access key in the storage.
    ///
    /// - Throws: `KeyValueStorageError.dataSerializationFailure` if the attempt to serialize
    ///             a value for storage purposes fails.
    func update(_ value: Codable, forKey key: String) throws

    /// Read data for given key.
    ///
    /// - Parameter key: An access key in the storage.
    ///
    /// - Throws: `KeyValueStorageError.noValueForKey` if there was no value for the requested key.
    func delete(forKey key: String) throws
}
