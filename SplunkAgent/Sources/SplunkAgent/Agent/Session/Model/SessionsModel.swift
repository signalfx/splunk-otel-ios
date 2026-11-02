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

internal import CiscoLogger
import Foundation
internal import SplunkCommon

/// Stores and manages available sessions.
class SessionsModel {

    // MARK: - Static constants

    /// Maximum number of managed sessions.
    static let maxDataCapacity: Int = 100

    /// Maximum lifetime of managed records.
    ///
    /// The value corresponds to 31 days.
    static let maxDataLifetime: TimeInterval = 2_678_400


    // MARK: - Private

    var storage: KeyValueStorage
    let storageKey: String
    private let logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "Agent")


    // MARK: - Public

    /// An array of all available sessions in this instance.
    var sessions: [SessionItem] = []


    // MARK: - Initialization

    /// Initializes a new instance that manages sessions.
    ///
    /// - Parameters:
    ///   - named: The `String` with name of this session list.
    ///   - storage: Instance of key-value storage for data persistence.
    init(named: String = "sessions", storage: KeyValueStorage = UserDefaultsStorage()) {
        storageKey = named
        self.storage = storage

        // Adds previously cached data
        sessions = read()
    }
}


extension SessionsModel {

    // MARK: - Storage management

    /// Saves actual state into permanent cache.
    func sync() {
        try? storage.update(sessions, forKey: storageKey)
    }

    /// Performs a cache purge by deleting entries that are too old or bloated.
    func purge() {
        // Too old records
        let monthAgo = Date() - Self.maxDataLifetime
        delete(before: monthAgo)

        // Exceeding capacity
        delete(exceedingOrder: Self.maxDataCapacity)
    }
}


extension SessionsModel {

    // MARK: - Storage utils

    /// Reads model data from cache.
    ///
    /// A decode failure is logged and yields an empty history. The whole array is stored under one
    /// key, so such a failure discards all of it.
    private func read() -> [SessionItem] {
        do {
            let cachedSessions: [SessionItem]? = try storage.read(forKey: storageKey)

            return cachedSessions ?? []
        }
        catch {
            logger.log(level: .error) {
                "Could not decode stored sessions, so session history starts empty: \(error)"
            }

            return []
        }
    }

    /// Deletes all records that were created before the specified date.
    ///
    /// - Parameter timestamp: The decisive moment for deleting records.
    func delete(before timestamp: Date) {
        sessions.removeAll { item in
            item.start <= timestamp
        }
    }

    /// Deletes all old records whose number exceeds the specified number.
    ///
    /// - Parameter position: Position in ordered data from newest to oldest.
    func delete(exceedingOrder position: Int) {
        guard sessions.count > position else {
            return
        }

        // At first we need to order data by start timestamp
        let orderedSessions = sessions.sorted { firstItem, secondItem in
            firstItem.start < secondItem.start
        }

        // Creates and updates list of session items without
        // too old items according to their desired order
        let firstUsedIndex = sessions.count - position
        let updatedSlice = orderedSessions[firstUsedIndex ..< sessions.count]
        let updatedSessions = Array(updatedSlice)

        sessions = updatedSessions
    }
}
