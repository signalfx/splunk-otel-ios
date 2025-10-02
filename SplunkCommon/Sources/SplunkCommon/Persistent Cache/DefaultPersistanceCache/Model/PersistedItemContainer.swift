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

/// The protocol defines the container for the persisted
/// item and its basic associated properties.
protocol PersistedItemContainer: Sendable, Codable {

    // MARK: - Associated types

    /// Type of the persisted item.
    associatedtype Item: Sendable, Codable


    // MARK: - Public

    /// The moment when the item was added or updated.
    ///
    /// This property is updated by persistent cache.
    var updated: Date { get set }

    /// Holds the value of the persisted item.
    var value: Item { get set }


    // MARK: - Initialization

    /// Initialize new container for persisted item.
    ///
    /// - Parameters:
    ///   - value: The value of the persisted item.
    ///   - updated: The moment when the item was added or updated.
    init(value: Item, updated: Date)
}
