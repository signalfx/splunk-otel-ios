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

import Foundation
import SplunkCommon

/// Runtime attributes with values that a test sets.
///
/// A test can change `sessionId` while spans start on other threads, so `lock` guards the stored values.
final class MockRuntimeAttributes: RuntimeAttributes {

    // MARK: - Private

    private let lock = NSLock()
    private var values: [String: Any]


    // MARK: - Initialization

    init(all: [String: Any] = [:]) {
        values = all
    }

    convenience init(sessionId: String?) {
        self.init()
        self.sessionId = sessionId
    }


    // MARK: - RuntimeAttributes

    var all: [String: Any] {
        lock.lock()
        defer { lock.unlock() }

        return values
    }


    // MARK: - Session

    /// The `session.id` value, or `nil` when the attributes carry none.
    var sessionId: String? {
        get {
            all["session.id"] as? String
        }
        set {
            lock.lock()
            defer { lock.unlock() }

            if let newValue {
                values["session.id"] = newValue
            }
            else {
                values.removeValue(forKey: "session.id")
            }
        }
    }
}
