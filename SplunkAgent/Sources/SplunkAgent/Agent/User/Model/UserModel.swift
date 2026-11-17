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

    private static let identifierKey = "userIdentifier"

    private var trackingModeValue: UserTrackingMode = .default
    private var identifierValue: String?


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

    /// The anonymous identifier for the user.
    ///
    /// The first read takes the identifier from the permanent cache. If there is none,
    /// it generates a new identifier and stores it in the permanent cache.
    /// Later reads return the same value from memory.
    ///
    /// It is safe to read from several threads at once; all of them get the same identifier.
    var identifier: String {
        let result = accessQueue.sync { () -> (identifier: String, isNew: Bool) in
            if let identifierValue {
                return (identifierValue, false)
            }

            let prepared = prepareIdentifier()
            identifierValue = prepared.identifier

            return prepared
        }

        // We store a new identifier only after we leave the access queue.
        // `UserDefaults` posts its change notification synchronously on this thread,
        // so app code can run here and read the identifier or the tracking mode again.
        if result.isNew {
            try? storage.insert(result.identifier, forKey: Self.identifierKey)
        }

        return result.identifier
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

    /// Reads the stored anonymous identifier, or generates a new one.
    ///
    /// - Note: Call this method only on `accessQueue`. It does not store a new
    ///         identifier. The caller stores it after it leaves the queue.
    ///
    /// - Returns: The identifier, and `isNew` set to `true` if the caller must store it.
    private func prepareIdentifier() -> (identifier: String, isNew: Bool) {
        // At first, we try to read the identifier from the permanent cache
        let storedIdentifier: String? = try? storage.read(forKey: Self.identifierKey)

        if let storedIdentifier {
            return (storedIdentifier, false)
        }

        // No cached identifier. We create a new one, and the caller stores it.
        return (String.uniqueHexIdentifier(ofLength: 32), true)
    }
}
