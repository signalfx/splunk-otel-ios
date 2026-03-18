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

/// A cross-platform data model that encapsulates session properties required to transfer
/// a session from one agent to another.
///
/// This type is not intended for the hosting application to inspect individual fields
/// and is effectively opaque to customers.
struct SessionMetadata: Codable {

    // MARK: - Properties

    /// The active session ID generated and managed by the SDK session manager.
    let sessionId: String

    /// The current anonymous user ID from user tracking mode.
    ///
    /// `nil` when user tracking is disabled; non-nil when anonymous tracking is enabled.
    let anonymousUserId: String?

    /// Unix timestamp (ms) representing when the current session was created.
    let sessionStart: Int64

    /// Unix timestamp (ms) representing the latest tracked activity for the current session.
    ///
    /// Falls back to ``sessionStart`` if no activity has been tracked yet.
    let sessionLastActivity: Int64


    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case sessionId
        case anonymousUserId
        case sessionStart
        case sessionLastActivity
    }
}
