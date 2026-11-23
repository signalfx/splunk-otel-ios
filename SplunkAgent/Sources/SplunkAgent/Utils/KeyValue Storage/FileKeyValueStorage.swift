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

internal import CiscoLogger
import Foundation
internal import SplunkCommon

/// A persistent key-value store that keeps each value in a file of its own.
///
/// A write is in the file system when the call returns. Unlike `UserDefaults`, it does not depend on
/// the preferences daemon, which can delay a write by seconds, so a crash shortly after the write
/// does not lose the value.
final class FileKeyValueStorage: KeyValueStorage {

    // MARK: - Private

    private let fileManager = FileManager.default
    private let logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "Agent")


    // MARK: - Public

    /// The directory that holds the files of this store.
    let directory: URL


    // MARK: - Initialization

    /// Initializes a store in the given directory, which is created at the first write.
    ///
    /// - Parameter directory: The directory that holds the files of this store.
    init(directory: URL) {
        self.directory = directory
    }

    /// Initializes a store in a directory of the given name inside the agent's application support directory.
    ///
    /// - Parameter name: The name of the store's directory.
    convenience init(named name: String) {
        let applicationSupport =
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory

        self.init(
            directory:
                applicationSupport
                .appendingPathComponent(PackageIdentifier.default, isDirectory: true)
                .appendingPathComponent(name, isDirectory: true)
        )
    }


    // MARK: - KeyValueStorage methods

    func insert(_ value: Codable, forKey key: String) throws {
        guard !fileManager.fileExists(atPath: fileURL(for: key).path) else {
            throw KeyValueStorageError.insertIntoExistingKey
        }

        try update(value, forKey: key)
    }

    func read<T: Codable>(forKey key: String) throws -> T? {
        let url = fileURL(for: key)

        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        let data = try Data(contentsOf: url)

        guard let value = try? JSONDecoder().decode(T.self, from: data) else {
            logger.log(level: .info) {
                "Read operation for key: \(key) failed while decoding data for type \(T.self)."
            }

            throw KeyValueStorageError.storedTypeMismatch
        }

        return value
    }

    func update(_ value: Codable, forKey key: String) throws {
        guard let data = try? JSONEncoder().encode(value) else {
            throw KeyValueStorageError.dataSerializationFailure
        }

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        // The atomic write never leaves a partly written file behind
        try data.write(to: fileURL(for: key), options: .atomic)
    }

    func delete(forKey key: String) throws {
        let url = fileURL(for: key)

        guard fileManager.fileExists(atPath: url.path) else {
            throw KeyValueStorageError.noValueForKey
        }

        try fileManager.removeItem(at: url)
    }


    // MARK: - Private methods

    private func fileURL(for key: String) -> URL {
        directory.appendingPathComponent("\(key).json", isDirectory: false)
    }
}
