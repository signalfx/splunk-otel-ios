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

import Foundation
import SplunkCommon

@testable import SplunkAgent

/// A storage whose saves of the held session starts block until the test unblocks them.
///
/// Other keys pass through at once. A blocked save gives up after a while, so that a regression fails
/// the test instead of hanging it.
final class BlockingHeldStartStorage: KeyValueStorage {

    // MARK: - Private

    private let storage: KeyValueStorage
    private let gate = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var isBlocking = true
    private var writtenSaves = 0


    // MARK: - Recorded saves

    /// The number of saves of the held session starts written so far.
    var writtenHeldStartSaves: Int {
        lock.withLock { writtenSaves }
    }


    // MARK: - Initialization

    init(wrapping storage: KeyValueStorage) {
        self.storage = storage
    }


    // MARK: - Blocking

    /// Lets the blocked saves and all later saves through.
    func unblock() {
        let wasBlocking = lock.withLock {
            defer { isBlocking = false }

            return isBlocking
        }

        if wasBlocking {
            gate.signal()
        }
    }


    // MARK: - CRUD operations

    func insert(_ value: Codable, forKey key: String) throws {
        try storage.insert(value, forKey: key)
    }

    func read<T: Codable>(forKey key: String) throws -> T? {
        try storage.read(forKey: key)
    }

    func update(_ value: Codable, forKey key: String) throws {
        if key == HeldSessionStartStore.storageKey, lock.withLock({ isBlocking }) {
            // One blocked save at a time: the store writes in order on its own serial queue
            _ = gate.wait(timeout: .now() + 20)
            gate.signal()
        }

        try storage.update(value, forKey: key)

        if key == HeldSessionStartStore.storageKey {
            lock.withLock { writtenSaves += 1 }
        }
    }

    func delete(forKey key: String) throws {
        try storage.delete(forKey: key)
    }
}
