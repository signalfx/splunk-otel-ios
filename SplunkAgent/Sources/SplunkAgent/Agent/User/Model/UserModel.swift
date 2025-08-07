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

/// Stores and manages user data.
class UserModel {

    // MARK: - Internal

    private let storage: KeyValueStorage
    private let accessQueue: DispatchQueue


    // MARK: - Private

    private var trackingModeValue: UserTrackingMode = .default


    // MARK: - Public

    /// The currently used tracking mode.
    var trackingMode: UserTrackingMode {
        get {
            accessQueue.sync {
                trackingModeValue
            }
        }
        set {
            accessQueue.async(flags: .barrier) {
                self.trackingModeValue = newValue
            }
        }
    }


    // MARK: - Initialization

    /// Initializes a new instance that manages user data.
    ///
    /// - Parameter storage: Instance of key-value storage for data persistence.
    init(storage: KeyValueStorage = UserDefaultsStorage()) {
        self.storage = storage

        let queueName = PackageIdentifier.default(named: "userModelAccess")
        accessQueue = DispatchQueue(label: queueName)
    }
}


extension UserModel {

    // MARK: - Business logic

    /// Reads or generates an anonymous identifier for the user.
    ///
    /// - Returns: A string with the anonymous identifier.
    func prepareIdentifier() -> String {
        let key = "userIdentifier"

        // At first, we try to read the identifier from the permanent cache
        let identifier: String? = try? storage.read(forKey: key)

        if let identifier {
            return identifier
        }

        // No cached identifier; we need to create a new one and cache it
        let newIdentifier = String.uniqueHexIdentifier(ofLength: 32)
        try? storage.insert(newIdentifier, forKey: key)

        return newIdentifier
    }
}
