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

@testable import SplunkAgent

public class PersistentSessionsValidator {

    // MARK: - Basic checks

    static func findPersistentMatches(with sessions: [SessionItem], keysPrefix: String, storageKey: String) -> [SessionItem] {
        let storage = UserDefaultsStorage()
        storage.keysPrefix = keysPrefix

        // Retrieves items from the storage
        let readSessions: [SessionItem]? = try? storage.read(forKey: storageKey)

        // Filter only matching with storage state
        let matchingSessions = sessions.compactMap { sessionItem in
            let found = readSessions?.contains(where: { readSessionItem in
                readSessionItem == sessionItem
            }) ?? false

            return found ? sessionItem : nil
        }

        return matchingSessions
    }
}
