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

/// Defines basic behavior and capabilities for a persistent cache that stores elements as key-value pairs.
public protocol AgentPersistentCache<Element>: Sendable {

    // MARK: - Associated types

    /// Type of the persisted element.
    associatedtype Element: Codable & Sendable


    // MARK: - Public

    /// The name of the cache in which the data will be stored in the repository.
    ///
    /// The name must be unique within its context. If data is stored through
    /// multiple cache instances side by side in a single place, it should have a unique name.
    var uniqueCacheName: String { get }

    /// The maximum number of elements the cache can hold.
    var maximumCapacity: Int { get }

    /// The maximum age of a cached element in seconds. If `nil`, elements do not expire based on age.
    var maximumLifetime: TimeInterval? { get }

    /// Determines if the cache content has already been restored following initialization.
    var isRestored: Bool { get async }


    // MARK: - Keys and values

    /// A collection containing just the keys for elements.
    var keys: [String] { get async }

    /// A collection containing just the values for elements.
    var values: [Element] { get async }


    // MARK: - Custom filtering

    /// Returns a dictionary of elements that were last modified within the specified date range.
    ///
    /// Passing `nil` for `start` or `end` creates an open-ended range. If both are `nil`, all elements are returned.
    ///
    /// - Parameters:
    ///   - start: The beginning of the date range.
    ///   - end: The end of the date range.
    ///
    /// - Returns: A dictionary containing the filtered key-value pairs.
    func elements(from start: Date?, to end: Date?) async -> [String: Element]


    // MARK: - CRUD operations

    /// Reads element value for a given key from the persistent cache.
    ///
    /// - Parameter key: An element access key in the persistent cache.
    ///
    /// - Returns: Previously cached data or `nil`.
    func value(forKey key: String) async throws -> Element?

    /// Updates element value for a given key in the persistent cache.
    ///
    /// If there is no data associated with this key, a new element will be inserted.
    ///
    /// - Parameters:
    ///   - element: New version of cached element.
    ///   - key: An element access key in the persistent cache.
    func update(_ element: Element, forKey key: String) async throws

    /// Removes element for a given key from persistent cache.
    ///
    /// - Parameter key: An element access key in the persistent cache.
    func remove(forKey key: String) async throws


    // MARK: - Storage management

    /// Persists the current in-memory state of the cache to storage.
    func sync() async throws
}
