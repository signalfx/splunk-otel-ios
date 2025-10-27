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

@testable import SplunkCommon

final class DefaultPersistentCacheTestBuilder {

    // MARK: - Basic builds

    static func build(named: String, maximumCapacity: Int? = nil, maximumLifetime: TimeInterval? = nil) -> DefaultPersistentCache<Int> {
        // Build cache with preconfigured storage
        let storage = FilesystemDiskStorage(
            prefix: FilesystemPrefix(module: "Tests"),
            rules: .default,
            encryption: NoneEncryption()
        )

        return DefaultPersistentCache<Int>(
            cacheName: named,
            diskStorage: storage,
            maximumCapacity: maximumCapacity,
            maximumLifetime: maximumLifetime
        )
    }
}
