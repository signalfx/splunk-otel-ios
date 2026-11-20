//
/*
Copyright 2026 Splunk Inc.

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

/// A held session start as it is saved in storage.
///
/// The app can end before a held start is released, for example in a crash before the session's
/// first telemetry is exported. The session's late telemetry, such as its crash report, is then
/// sent at the next launch and releases the start restored from this record.
///
/// Fields added later must be optional, so that records saved by an older version still decode.
struct HeldSessionStartRecord: Codable, Equatable {
    let sessionId: String
    let start: Date
    let previousSessionId: String?
    let screenName: String?
}

/// Saves the held session starts, so that the next launch can restore them.
///
/// Saves run in order on a serial queue of their own, so the session's access queue never waits
/// for storage. A storage call can block for seconds, and `UserDefaults` posts its change
/// notification on the writing thread, where app code may read the current session id through
/// the session's access queue.
final class HeldSessionStartStore {

    // MARK: - Static constants

    /// The storage key of the saved held session starts.
    static let storageKey = "heldSessionStarts"


    // MARK: - Private

    private let storage: KeyValueStorage
    private let queue: DispatchQueue
    private let logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "Agent")


    // MARK: - Initialization

    /// Initializes a store that keeps the held session starts in the given storage.
    ///
    /// - Parameter storage: Instance of key-value storage for data persistence.
    init(storage: KeyValueStorage) {
        self.storage = storage

        queue = DispatchQueue(label: PackageIdentifier.default(named: "heldSessionStartsStorage"))
    }


    // MARK: - Saving and loading

    /// Saves the held session starts after the saves already requested, without waiting for the write.
    ///
    /// - Parameter records: All held session starts, oldest first.
    func save(_ records: [HeldSessionStartRecord]) {
        queue.async { [storage, logger] in
            do {
                try storage.update(records, forKey: Self.storageKey)
            }
            catch {
                logger.log(level: .error) {
                    "Could not save the held session starts: \(error)"
                }
            }
        }
    }

    /// Loads the saved held session starts, after the saves already requested are written.
    ///
    /// Must not be called on a queue that a save may wait for, such as the session's access queue.
    ///
    /// - Returns: The saved held session starts, oldest first, or an empty array if none can be read.
    func load() -> [HeldSessionStartRecord] {
        queue.sync {
            do {
                return try storage.read(forKey: Self.storageKey) ?? []
            }
            catch {
                logger.log(level: .error) {
                    "Could not read the saved held session starts, so none are restored: \(error)"
                }

                return []
            }
        }
    }

    /// Waits until the saves already requested are written.
    ///
    /// Tests use it to simulate the next launch of the app after the saves reached storage.
    func waitForRequestedSaves() {
        queue.sync {}
    }
}
