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

/// Definition of a basic generic memorizer for processed events.
///
/// It records and stores information about events. The most common use
/// is to store information that an event has already occurred for a given session,
/// even between individual runs of the application.
protocol EventMemorizer {

    // MARK: - Public

    /// The name of the memorizer.
    ///
    /// The used name should be unique whenever possible.
    var name: String { get }

    /// Determines if the memorizer is operational and all its data is available.
    var isReady: Bool { get async }


    // MARK: - Memorizer methods

    /// Checks if an event corresponding to the given key has already been memorized.
    ///
    /// - Parameter eventKey: The unique key representing the event.
    ///
    /// - Returns: `true` if the event for this key has already been memorized.
    ///
    /// - Throws: Re-throws errors from embedded objects, mainly from the persistent store layer.
    func isMemorized(eventKey: String) async throws -> Bool

    /// Marks an event corresponding to the given key as memorized.
    ///
    /// - Parameter eventKey: The unique key representing the event.
    ///
    /// - Throws: Re-throws errors from embedded objects, mainly from the persistent store layer.
    func markAsMemorized(eventKey: String) async throws

    /// Checks whether the event with the specified key has already been memorized,
    /// and if not, marks it as memorized.
    ///
    /// - Parameter eventKey: The unique key representing the event.
    ///
    /// - Returns: `true` if the event had not been memorized before and is now marked as memorized;
    ///           `false` if it was already memorized.
    ///
    /// - Throws: Propagates errors from internal objects, mainly from the persistence layer.
    func checkAndMarkIfNeeded(eventKey: String) async throws -> Bool
}
