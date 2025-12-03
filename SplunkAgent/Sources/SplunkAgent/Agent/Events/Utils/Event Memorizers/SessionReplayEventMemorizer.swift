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

final class SessionReplayEventMemorizer: EventMemorizer {

    // MARK: - Static constants

    /// Maximum number of managed items.
    static let maximumCapacity: Int = 100

    /// Maximum lifetime of managed items.
    ///
    /// The value corresponds to 31 days.
    static let maximumLifetime: TimeInterval = 2_678_400


    // MARK: - Private

    var memorizerCache: any AgentPersistentCache<Bool>


    // MARK: - Public

    let name: String

    var isReady: Bool {
        get async {
            await memorizerCache.isRestored
        }
    }


    // MARK: - Initialization

    init(named: String) {
        name = named

        memorizerCache = DefaultPersistentCache(
            uniqueCacheName: "\(named)MemorizerCache",
            maximumCapacity: Self.maximumCapacity,
            maximumLifetime: Self.maximumLifetime
        )
    }


    // MARK: - Memorizer methods

    func isMemorized(eventKey: String) async throws -> Bool {
        try await memorizerCache.value(forKey: eventKey) ?? false
    }

    func markAsMemorized(eventKey: String) async throws {
        try await memorizerCache.update(true, forKey: eventKey)
    }
}
