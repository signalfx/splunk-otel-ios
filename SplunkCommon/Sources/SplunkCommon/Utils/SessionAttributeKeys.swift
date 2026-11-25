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

/// Keys of the session attributes and the shape of the agent's session ID.
///
/// Only the agent sets these attributes. Every module that filters, checks or generates them uses
/// these constants, so the rules stay the same in all places.
package enum SessionAttributeKeys {

    /// The attribute that carries the ID of the session a signal belongs to.
    package static let sessionId = "session.id"

    /// The attribute that carries the ID of the session that came before, on a `session.start` event.
    package static let previousSessionId = "session.previous_id"

    /// The session attributes that only the agent sets.
    ///
    /// A value an app supplies under one of these keys is ignored or removed.
    package static let agentOnly = [sessionId, previousSessionId]

    /// The number of characters in an agent session ID.
    package static let agentSessionIdLength = 32

    /// Whether `digit` is a character an agent session ID can hold: a UTF-8 digit `0` to `9` or a
    /// lowercase letter `a` to `f`.
    package static func isAgentSessionIdDigit(_ digit: UInt8) -> Bool {
        (digit >= UInt8(ascii: "0") && digit <= UInt8(ascii: "9"))
            || (digit >= UInt8(ascii: "a") && digit <= UInt8(ascii: "f"))
    }
}
