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

import CiscoDiskStorage
import CiscoEncryption
import Foundation

@testable import SplunkAgent
@testable import SplunkCommon

final class SessionReplayMemorizerTestBuilder {

    // MARK: - Static constants

    private static let moduleName = "Tests"


    // MARK: - Basic builds

    static func build(named: String) async throws -> SessionReplayEventMemorizer {
        // Build cache with preconfigured storage
        let storage = FilesystemDiskStorage(
            prefix: FilesystemPrefix(module: moduleName),
            rules: .default,
            encryption: NoneEncryption()
        )

        let cacheName = cacheName(for: named)
        let cache = DefaultPersistentCache<Bool>(
            cacheName: cacheName,
            diskStorage: storage,
            maximumCapacity: nil,
            maximumLifetime: nil
        )

        // Init is async, need to wait
        try await Task.sleep(nanoseconds: 1_000_000_000)

        // Build memorizer with preconfigured persistent cache
        let memorizer = SessionReplayEventMemorizer(named: named)
        memorizer.memorizerCache = cache

        return memorizer
    }


    // MARK: - Storage utils

    static func removeStorage(named: String) throws {
        let storage = FilesystemDiskStorage(
            prefix: FilesystemPrefix(module: moduleName),
            rules: .default,
            encryption: NoneEncryption()
        )

        let fileKey = KeyBuilder(cacheName(for: named))
        try storage.delete(forKey: fileKey)
    }


    // MARK: - Private methods

    private static func cacheName(for named: String) -> String {
        "\(named)MemorizerCache"
    }
}
