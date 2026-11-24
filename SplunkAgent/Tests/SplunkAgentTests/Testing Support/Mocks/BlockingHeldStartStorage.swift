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

/// A storage whose saves or reads of the held session starts block until the test unblocks them.
///
/// Other keys, and the calls of the kind that is not blocked, pass through at once. A blocked call gives up
/// after a while, so that a regression fails the test instead of hanging it.
final class BlockingHeldStartStorage: KeyValueStorage {

    // MARK: - Blocked calls

    /// The kind of storage call that blocks.
    enum BlockedCall {
        /// Saves of the held session starts block.
        case save

        /// Reads of the held session starts block.
        case read
    }


    // MARK: - Private

    private let storage: KeyValueStorage
    private let blockedCall: BlockedCall
    private let gate = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var isBlocking = true
    private var writtenSaves = 0
    private var finishedReads = 0
    private var blockedReadHandler: (() -> Void)?


    // MARK: - Recorded saves

    /// The number of saves of the held session starts written so far.
    var writtenHeldStartSaves: Int {
        lock.withLock { writtenSaves }
    }

    /// The number of reads of the held session starts finished so far.
    var finishedHeldStartReads: Int {
        lock.withLock { finishedReads }
    }

    /// The held session starts in the wrapped storage now, read without blocking or counting the read.
    func storedHeldStarts() throws -> [HeldSessionStartRecord]? {
        try storage.read(forKey: HeldSessionStartStore.storageKey)
    }

    /// A closure called when a read of the held session starts begins to wait, on the reading thread.
    var didBlockRead: (() -> Void)? {
        get { lock.withLock { blockedReadHandler } }
        set { lock.withLock { blockedReadHandler = newValue } }
    }


    // MARK: - Initialization

    /// Initializes a storage that wraps `storage` and blocks the given kind of call for the held session starts.
    init(wrapping storage: KeyValueStorage, blocking blockedCall: BlockedCall = .save) {
        self.storage = storage
        self.blockedCall = blockedCall
    }


    // MARK: - Blocking

    /// Lets the blocked calls and all later calls through.
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
        guard key == HeldSessionStartStore.storageKey else {
            return try storage.read(forKey: key)
        }

        if blockedCall == .read, lock.withLock({ isBlocking }) {
            didBlockRead?()
            waitAtGate()
        }

        defer {
            lock.withLock { finishedReads += 1 }
        }

        return try storage.read(forKey: key)
    }

    func update(_ value: Codable, forKey key: String) throws {
        if key == HeldSessionStartStore.storageKey, blockedCall == .save, lock.withLock({ isBlocking }) {
            waitAtGate()
        }

        try storage.update(value, forKey: key)

        if key == HeldSessionStartStore.storageKey {
            lock.withLock { writtenSaves += 1 }
        }
    }

    func delete(forKey key: String) throws {
        try storage.delete(forKey: key)
    }


    // MARK: - Private methods

    private func waitAtGate() {
        // One blocked call at a time: the store calls storage in order on its own serial queue
        _ = gate.wait(timeout: .now() + 20)
        gate.signal()
    }
}
