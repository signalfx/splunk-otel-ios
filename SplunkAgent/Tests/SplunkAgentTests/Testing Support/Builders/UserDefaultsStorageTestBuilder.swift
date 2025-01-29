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

final class UserDefaultsStorageTestBuilder {

    // MARK: - Static constants

    public static let defaultKey = "sessions"


    // MARK: - Basic builds

    public static func buildCleanStorage(named: String) -> KeyValueStorage {
        let keysPrefix = "\(PackageIdentifier.default).\(named)."

        // Clean storage before test run
        UserDefaultsUtils.cleanItem(prefix: keysPrefix, key: defaultKey)

        let storage = UserDefaultsStorage()
        storage.keysPrefix = keysPrefix

        return storage
    }
}
