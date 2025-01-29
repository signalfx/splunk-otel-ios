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

class DefaultUser: AgentUser {

    // MARK: - Private

    var storage: KeyValueStorage


    // MARK: - Public

    private(set) lazy var userIdentifier: String = prepareIdentifier()


    // MARK: - Initialization

    init(storage: KeyValueStorage = UserDefaultsStorage()) {
        self.storage = storage
    }


    // MARK: - Business logic

    private func prepareIdentifier() -> String {
        let key = "userIdentifier"

        // At first, we try to read the identifier from the permanent cache
        let identifier: String? = try? storage.read(forKey: key)

        if let identifier {
            return identifier
        }

        // No cached identifier. We need to create a new one and cache it.
        let newIdentifier = String.uniqueIdentifier()
        try? storage.insert(newIdentifier, forKey: key)

        return newIdentifier
    }
}
