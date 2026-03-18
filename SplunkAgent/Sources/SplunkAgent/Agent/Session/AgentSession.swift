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

/// Defines the basic properties and behavior of the session manager.
protocol AgentSession {

    // MARK: - Identification

    /// Session identifier.
    var currentSessionId: String { get }

    /// Session item object holding session metadata.
    var currentSessionItem: SessionItem { get }

    /// Session identifier history.
    func sessionId(for timestamp: Date) -> String?

    /// The timestamp when the current session was created.
    var currentSessionStart: Date { get }

    /// The latest tracked activity timestamp for the current session.
    ///
    /// Falls back to ``currentSessionStart`` if no activity has been tracked yet.
    var currentSessionLastActivity: Date { get }

    /// Records a telemetry activity event for the current session.
    ///
    /// - Parameter date: The timestamp of the activity.
    func trackActivity(at date: Date)


    // MARK: - Session change notifications

    /// A notification that posts before the current session will be changed.
    ///
    /// The `object` of the notification is a string with the ID of the closed session.
    /// There is no `userInfo` dictionary.
    static var sessionWillResetNotification: Notification.Name { get }

    /// A notification that posts after the current session did change.
    ///
    /// The `object` of the notification is a string with the ID of the new session.
    /// There is no `userInfo` dictionary.
    static var sessionDidResetNotification: Notification.Name { get }
}


extension AgentSession {

    // MARK: - Session change notifications

    static var sessionWillResetNotification: Notification.Name {
        Notification.Name(
            PackageIdentifier.default(named: "session-will-reset")
        )
    }

    static var sessionDidResetNotification: Notification.Name {
        Notification.Name(
            PackageIdentifier.default(named: "session-did-reset")
        )
    }
}
