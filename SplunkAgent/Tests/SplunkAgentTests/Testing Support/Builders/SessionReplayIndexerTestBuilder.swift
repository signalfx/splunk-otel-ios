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

final class SessionReplayIndexerTestBuilder {

    // MARK: - Static constants

    private static let moduleName = "Tests"


    // MARK: - Basic builds

    static func build(named: String) -> SessionReplayEventIndexer {
        // Build cache with preconfigured storage
        let storage = FilesystemDiskStorage(
            prefix: FilesystemPrefix(module: moduleName),
            rules: .default,
            encryption: NoneEncryption()
        )

        let cacheName = cacheName(for: named)
        let cache = DefaultPersistentCache<Int>(
            cacheName: cacheName,
            diskStorage: storage,
            maximumCapacity: nil,
            maximumLifetime: nil
        )

        // Build indexer with preconfigured persistent cache
        let indexer = SessionReplayEventIndexer(named: named)
        indexer.indexCache = cache

        return indexer
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
        "\(named)IndexCache"
    }
}
