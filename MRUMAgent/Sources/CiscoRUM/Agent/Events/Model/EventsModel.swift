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

/// Stores persisted information required for event management.
class EventsModel {

    // MARK: - Constants

    let maxSentSessionStarts = 20


    // MARK: - Private

    let storageKeyPrefix: String
    var storage: KeyValueStorage

    // Session starts
    var sendingSessionStartIDs = [String]()
    var sentSessionStartIDs = [String]()

    // Keys identifying items in the storage
    private enum StorageKeys: String {
        case sentSessionStarts
    }


    // MARK: - Initialization

    /// Initializes a new instance that manages events storage.
    ///
    /// - Parameters:
    ///   - named: Storage identifier, used in item identifiers, uniquely identifying each item in the storage.
    ///   - storage: Instance of key-value storage for data persistence.
    init(named: String = "events", storage: KeyValueStorage = UserDefaultsStorage()) {
        storageKeyPrefix = named
        self.storage = storage

        load()
    }


    // MARK: - Storage

    func load() {
        let storedSentIDs: [String]? = try? storage.read(forKey: storageKey(event: .sentSessionStarts))

        if let storedSentIDs {
            sentSessionStartIDs.append(contentsOf: storedSentIDs)
        }
    }

    func sync() {
        // Clip the array so that only last x events are stored to save space
        if sentSessionStartIDs.count > maxSentSessionStarts {
            sentSessionStartIDs.removeFirst(sentSessionStartIDs.count - maxSentSessionStarts)
        }

        try? storage.update(sentSessionStartIDs, forKey: storageKey(event: .sentSessionStarts))
    }

    func clear(andSync: Bool = true) {
        sentSessionStartIDs.removeAll()
        sendingSessionStartIDs.removeAll()

        if andSync {
            sync()
        }
    }

    private func storageKey(event: StorageKeys) -> String {
        let eventKey = event.rawValue
        let storageKey = "\(storageKeyPrefix).\(eventKey)"

        return storageKey
    }


    // MARK: - Session start events

    func markSessionStartSending(_ sessionID: String) {
        sendingSessionStartIDs.append(sessionID)
    }

    func markSessionStartSent(_ sessionID: String) {
        // Remove "sending" session id
        if let index = sendingSessionStartIDs.firstIndex(of: sessionID) {
            sendingSessionStartIDs.remove(at: index)
        }

        // Mark "sent" session id
        sentSessionStartIDs.append(sessionID)
        sync()
    }

    func isSessionStartSending(_ sessionID: String) -> Bool {
        return sendingSessionStartIDs.contains(sessionID)
    }

    func isSessionStartSent(_ sessionID: String) -> Bool {
        return sentSessionStartIDs.contains(sessionID)
    }
}
