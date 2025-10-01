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
internal import SplunkCommon

/// Implementation of the indexer for events from the Session Replay module.
final class SessionReplayEventIndexer: EventIndexer {

    /// Maximum number of managed items.
    static let maximumCapacity: Int = 1_000

    /// Maximum lifetime of managed items.
    ///
    /// The value corresponds to 31 days.
    static let maximumLifetime: TimeInterval = 2_678_400


    // MARK: - Private

    var indexCache: any AgentPersistentCache<Int>


    // MARK: - Public

    let name: String

    var isReady: Bool {
        get async {
            await indexCache.isRestored
        }
    }


    // MARK: - Initialization

    /// Initializes the event indexer.
    ///
    /// - Parameter named: The name of the indexer.
    init(named: String) {
        name = named

        indexCache = DefaultPersistentCache(
            uniqueCacheName: "\(named)IndexCache",
            maximumCapacity: Self.maximumCapacity,
            maximumLifetime: Self.maximumLifetime
        )
    }


    // MARK: - Indexer method

    func prepareIndex(sessionId: String, eventTimestamp: Date) async throws -> Int {
        var eventIndex: Int

        let eventKey = eventKey(sessionId: sessionId, eventTimestamp: eventTimestamp)
        let processedKey = processedKey(sessionId: sessionId)

        // We try to get prepared corresponding chunk index
        let preparedEventIndex = try await indexCache.value(forKey: eventKey)

        // If it has not been prepared yet, we will create a new one
        if let preparedEventIndex {
            eventIndex = preparedEventIndex
        }
        else {
            let processedIndex = try await indexCache.value(forKey: processedKey) ?? 0
            eventIndex = processedIndex + 1

            // Save changes
            try await indexCache.update(eventIndex, forKey: eventKey)
            try await indexCache.update(eventIndex, forKey: processedKey)
        }

        return eventIndex
    }

    func removeIndex(sessionId: String, eventTimestamp: Date) async throws {
        let eventKey = eventKey(sessionId: sessionId, eventTimestamp: eventTimestamp)

        try await indexCache.remove(forKey: eventKey)
    }


    // MARK: - Private methods

    private func eventKey(sessionId: String, eventTimestamp: Date) -> String {
        let timestamp = eventTimestamp.timeIntervalSince1970

        return "\(sessionId).\(timestamp).eventIndex"
    }

    private func processedKey(sessionId: String) -> String {
        "\(sessionId).processedIndex"
    }
}
