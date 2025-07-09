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

/// Definition of a basic generic indexer for processed events.
protocol EventIndexer {

    // MARK: - Public

    /// The name of the indexer.
    ///
    /// The used name should be unique whenever possible.
    var name: String { get }


    // MARK: - Indexer methods

    /// Prepares and returns the appropriate index for the published event.
    ///
    /// The method also automatically updates the index cache for each event.
    ///
    /// - Parameters:
    ///   - sessionId: Identification of the session to which the event belongs.
    ///   - eventTimestamp: Event timestamp.
    ///
    /// - Returns: Pre-generated or newly created event index.
    func prepareIndex(sessionId: String, eventTimestamp: Date) async throws -> Int

    /// Removes pre-generated event index form the index cache.
    ///
    /// If no index has been generated for this event yet then it does nothing.
    ///
    /// - Parameters:
    ///   - sessionId: Identification of the session to which the event belongs.
    ///   - eventTimestamp: Event timestamp.
    func removeIndex(sessionId: String, eventTimestamp: Date) async throws
}
