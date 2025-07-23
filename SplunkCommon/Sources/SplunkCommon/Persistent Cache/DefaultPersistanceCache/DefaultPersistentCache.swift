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

internal import CiscoDiskStorage
internal import CiscoEncryption
internal import CiscoLogger

import Foundation

/// A concurrency-safe persistent cache that stores elements as key-value pairs.
public final class DefaultPersistentCache<Element: Codable & Sendable & Equatable>: AgentPersistentCache {

    // MARK: - Inline types

    typealias ElementContainer = DefaultItemContainer<Element>


    // MARK: - Private

    private nonisolated(unsafe) let storage: DiskStorage
    private nonisolated(unsafe) let cacheKey: KeyBuilder

    let model = PersistentCacheModel<ElementContainer>()

    private let logger = DefaultLogAgent(
        poolName: PackageIdentifier.instance(),
        category: "Agent"
    )


    // MARK: - Public

    /// The unique name identifying this cache instance.
    public let uniqueCacheName: String
    /// The maximum number of elements the cache can hold.
    public let maximumCapacity: Int
    /// The maximum duration for which an element is considered valid.
    ///
    /// If this value is `nil`, elements stored in the cache do not expire based on their age.
    public let maximumLifetime: TimeInterval?

    /// A Boolean value indicating whether the cache has finished its initial restoration from persistent storage.
    public var isRestored: Bool {
        get async {
            await model.isRestored
        }
    }


    // MARK: - Keys and values

    /// An array containing all the keys currently present in the cache.
    public var keys: [String] {
        get async {
            await Array(model.containers.keys)
        }
    }

    /// An array containing all the values currently present in the cache.
    public var values: [Element] {
        get async {
            await Array(model.containers.values).map(\.value)
        }
    }


    // MARK: - Initialization

    /// Initializes a new instance of the persistent cache.
    ///
    /// - Parameters:
    ///   - uniqueCacheName: The unique name of the cache.
    ///   - maximumCapacity: Maximum number of managed elements.
    ///   - maximumLifetime: Maximum lifetime of managed records.
    public convenience init(
        uniqueCacheName: String,
        maximumCapacity: Int? = nil,
        maximumLifetime: TimeInterval? = nil
    ) {
        self.init(
            cacheName: uniqueCacheName,
            maximumCapacity: maximumCapacity,
            maximumLifetime: maximumLifetime
        )
    }

    /// Initializes a new instance of the persistent cache.
    ///
    /// - Parameters:
    ///   - cacheName: The unique name of the cache.
    ///   - diskStorage: `DiskStorage` object used for data persistence.
    ///   - maximumCapacity: Maximum number of managed elements.
    ///   - maximumLifetime: Maximum lifetime of managed records.
    init(
        cacheName: String,
        diskStorage: DiskStorage = FilesystemDiskStorage(
            prefix: FilesystemPrefix(module: "Agent"),
            rules: .default
        ),
        maximumCapacity: Int?,
        maximumLifetime: TimeInterval?
    ) {
        storage = diskStorage
        cacheKey = .init(cacheName)

        uniqueCacheName = cacheName
        self.maximumCapacity = maximumCapacity ?? .max
        self.maximumLifetime = maximumLifetime

        // Setup to the operational state
        setup()
    }

    private func setup() {
        Task {
            do {
                // Reload and purge
                try await restore()
                await purge()

                // Re-Save updated state
                try await sync()

            } catch {
                logger.log(level: .warn, isPrivate: false) {
                    "Failed to initialize the cache: \n\t\(error)"
                }
            }
        }
    }


    // MARK: - Custom filtering

    /// Retrieves a dictionary of elements that were last updated within a specific date range.
    ///
    /// You can specify a start date, an end date, or both to define the time window for the filter.
    /// If both `start` and `end` are `nil`, this method returns all elements in the cache.
    ///
    /// - Parameters:
    ///   - start: The beginning of the date range. If `nil`, the range has no lower bound.
    ///   - end: The end of the date range. If `nil`, the range has no upper bound.
    /// - Returns: A dictionary where keys are the element identifiers and values are the elements themselves,
    ///   filtered by the specified date range.
    public func elements(from start: Date? = nil, to end: Date? = nil) async -> [String: Element] {
        await model.items(from: start, to: end)
    }


    // MARK: - CRUD operations

    /// Retrieves the element associated with a specific key.
    ///
    /// - Parameter key: The key for which to retrieve the element.
    /// - Returns: The element corresponding to the key, or `nil` if the key is not found.
    /// - Throws: An error if the value cannot be retrieved.
    public func value(forKey key: String) async throws -> Element? {
        await model.item(forKey: key)
    }

    /// Adds or updates an element in the cache for a given key.
    ///
    /// If an element with the same key already exists, its value is updated and its modification timestamp is refreshed.
    /// If the key does not exist, a new element is added. After the modification, the cache state is
    /// synchronized with the persistent storage.
    ///
    /// - Note: If an element with the same value already exists for the key, no update is performed, and the
    ///   cache is not synchronized to storage.
    ///
    /// - Parameters:
    ///   - element: The element to add or update.
    ///   - key: The key to associate with the element.
    /// - Throws: An error if the cache state cannot be synchronized to persistent storage after the update.
    public func update(_ element: Element, forKey key: String) async throws {
        let oldValue = try await value(forKey: key)

        if oldValue != element {
            await model.add(element, forKey: key)
            try await sync()
        }
    }

    /// Removes the element associated with the specified key from the cache.
    ///
    /// After removing the element, the cache state is synchronized with the persistent storage.
    ///
    /// - Parameter key: The key of the element to remove.
    /// - Throws: An error if the cache state cannot be synchronized to persistent storage after the removal.
    public func remove(forKey key: String) async throws {
        await model.remove(key: key)
        try await sync()
    }


    // MARK: - Storage management

    /// Saves actual state into storage.
    public func sync() async throws {
        let cacheKey: KeyBuilder = .init(uniqueCacheName)
        let containers = await model.containers

        let caches: [ItemInfo]? = try? storage.list(forKey: .init(""))
        let cacheExists = (caches ?? [])
            .contains(where: {
                $0.key == uniqueCacheName
            })

        // If it does not exist yet, insert the corresponding item
        if !cacheExists {
            try storage.insert(containers, forKey: cacheKey)

            return
        }

        try storage.update(containers, forKey: cacheKey)
    }

    /// Restores the last state from the storage.
    private func restore() async throws {
        let storedContainers: [String: ElementContainer]? = try storage.read(forKey: cacheKey)

        if let storedContainers {
            await model.restore(to: storedContainers)
        }

        // The restoration has been successfully completed
        await model.update(isRestored: true)
    }


    // MARK: - Maintenance methods

    /// Performs a cache purge by deleting entries that are too old or bloated.
    func purge() async {
        // Too old records
        if let maximumLifetime {
            let outdated = Date() - maximumLifetime
            await delete(before: outdated)
        }

        // Exceeding capacity
        await delete(exceedingOrder: maximumCapacity)
    }


    // MARK: - Purge methods

    /// Deletes all elements that were last updated before the specified date.
    ///
    /// - Parameter timestamp: The decisive moment for deleting records.
    private func delete(before timestamp: Date) async {
        let outdatedKeys = await model.items(to: timestamp).keys

        for key in outdatedKeys {
            await model.remove(key: key)
        }
    }

    /// Deletes all old elements whose number exceeds the specified number.
    ///
    /// - Parameter number: Position in ordered data from newest to oldest.
    private func delete(exceedingOrder position: Int) async {
        let containers = await model.containers

        guard containers.count > position else {
            return
        }

        // At first we need to order keys by updated timestamp
        let keysAndUpdates: [(key: String, update: Date)] = containers.map { key, value in
            (key, value.updated)
        }

        let sortedKeys = keysAndUpdates
            .sorted { first, second in
                first.update < second.update
            }
            .map { $0.key }

        // Creates list of keys with too old elements
        let firstUsedIndex = sortedKeys.count - position
        let oldKeysSlice = sortedKeys[0 ..< firstUsedIndex]
        let oldKeys = Array(oldKeysSlice)

        // Delete old elements from cache
        for key in oldKeys {
            await model.remove(key: key)
        }
    }
}
