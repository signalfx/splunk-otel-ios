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

/// A session object is a representation of the current user session.
public final class Session {

    // MARK: - Internal

    private unowned let owner: SplunkRum


    // MARK: - State

    /// An object that reflects the current session's state, a ``SessionState`` instance.
    public private(set) lazy var state = SessionState(for: owner)


    // MARK: - Initialization

    init(for owner: SplunkRum) {
        self.owner = owner
    }
}


extension Session {

    // MARK: - Metadata

    /// Session metadata serialized as a Base64-encoded JSON string.
    ///
    /// The returned value can be used to transfer a session from one agent to another.
    /// The format is opaque to the hosting application.
    ///
    /// Returns `nil` if the metadata cannot be serialized.
    public var metadata: String? {
        let session = owner.currentSession
        let user = owner.currentUser

        let anonymousUserId: String?

        if user.trackingMode != .noTracking {
            anonymousUserId = user.userIdentifier
        }
        else {
            anonymousUserId = nil
        }

        let sessionMetadata = SessionMetadata(
            sessionId: session.currentSessionId,
            anonymousUserId: anonymousUserId,
            sessionStart: Int64(session.currentSessionStart.timeIntervalSince1970 * 1_000),
            sessionLastActivity: Int64(session.currentSessionLastActivity.timeIntervalSince1970 * 1_000)
        )

        do {
            let jsonData = try JSONEncoder().encode(sessionMetadata)
            return jsonData.base64EncodedString()
        }
        catch {
            owner.logger.log(level: .error, isPrivate: false) {
                "Failed to serialize session metadata: \(error)"
            }
            return nil
        }
    }
}


extension Session {

    // MARK: - Notifications

    /// Posted before the current session is reset.
    ///
    /// The notification `object` is a `String` containing the session ID that is about to be closed.
    /// There is no `userInfo` dictionary.
    ///
    /// This notification is posted when the session is rotated due to inactivity timeout or
    /// maximum session length being exceeded. It is **not** posted when the initial session is
    /// created at startup or when the app terminates.
    ///
    /// ```swift
    /// NotificationCenter.default.addObserver(
    ///     forName: Session.sessionWillResetNotification,
    ///     object: nil,
    ///     queue: nil
    /// ) { notification in
    ///     let closingSessionId = notification.object as? String
    /// }
    /// ```
    public static let sessionWillResetNotification = DefaultSession.sessionWillResetNotification

    /// Posted after the current session has been reset.
    ///
    /// The notification `object` is a `String` containing the session ID of the new session.
    /// There is no `userInfo` dictionary.
    ///
    /// This notification is posted when the session is rotated due to inactivity timeout or
    /// maximum session length being exceeded. It is **not** posted when the initial session is
    /// created at startup or when the app terminates.
    ///
    /// ```swift
    /// NotificationCenter.default.addObserver(
    ///     forName: Session.sessionDidResetNotification,
    ///     object: nil,
    ///     queue: nil
    /// ) { notification in
    ///     let newSessionId = notification.object as? String
    /// }
    /// ```
    public static let sessionDidResetNotification = DefaultSession.sessionDidResetNotification
}


extension Session {

    // MARK: - Identifier

    /// Identification of recorded session in given time.
    ///
    /// Some events can be tracked with a delay caused by, e.g., its asynchronous pre-processing
    /// or an application crash.
    ///
    /// This method returns the respective session ID for the timestamp the event originates.
    ///
    /// - Parameter timestamp: The timestamp for which the session identifier is requested.
    ///
    /// - Returns: The corresponding `sessionId` or `nil` if the session did not exist at that time.
    public func sessionId(for timestamp: Date) -> String? {
        owner.currentSession.sessionId(for: timestamp)
    }
}
