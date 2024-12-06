//
/*
Copyright 2024 Splunk Inc.

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

/// Represents information about the life of one unique session.
struct SessionItem: Codable, Equatable {

    // MARK: - Public

    /// Identification of recorded session.
    public let id: String

    /// The moment when the session started.
    public let start: Date

    /// Marks this session as explicitly closed.
    public var closed: Bool?
}
