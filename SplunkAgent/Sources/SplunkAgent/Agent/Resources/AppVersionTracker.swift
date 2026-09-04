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

final class AppVersionTracker {

    // MARK: - Internal

    static let storageKey = "app.version.state"

    let previousVersion: String?


    // MARK: - Private

    private struct StoredState: Codable {
        let installationId: String
        let currentVersion: String
        let previousVersion: String?
    }


    // MARK: - Initialization

    init(currentVersion: String, storage: KeyValueStorage = UserDefaultsStorage()) {
        guard !currentVersion.isEmpty else {
            previousVersion = nil
            return
        }

        let installationId = AppInstallationStorage.identifier(using: storage)
        let storedState: StoredState? = try? storage.read(forKey: Self.storageKey)

        if let storedState,
           storedState.installationId == installationId,
           storedState.currentVersion == currentVersion {
            previousVersion = Self.nonEmpty(storedState.previousVersion)
        }
        else {
            previousVersion = nil
        }
    }

    static func record(currentVersion: String, storage: KeyValueStorage = UserDefaultsStorage()) {
        guard !currentVersion.isEmpty else {
            return
        }

        let installationId = AppInstallationStorage.identifier(using: storage)
        let storedState: StoredState? = try? storage.read(forKey: Self.storageKey)
        let previousVersion: String?

        if let storedState,
           storedState.installationId == installationId,
           !storedState.currentVersion.isEmpty {
            if storedState.currentVersion == currentVersion {
                previousVersion = Self.nonEmpty(storedState.previousVersion)
            }
            else {
                previousVersion = storedState.currentVersion
            }
        }
        else {
            previousVersion = nil
        }

        let newState = StoredState(
            installationId: installationId,
            currentVersion: currentVersion,
            previousVersion: previousVersion
        )
        try? storage.update(newState, forKey: Self.storageKey)
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else {
            return nil
        }

        return value
    }
}
