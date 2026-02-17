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


    // MARK: - Notifications

    /// A notification that posts whenever a session ID is set or changed.
    ///
    /// This notification is always posted on the **main thread**, making it safe to update
    /// UI directly from the observer without additional dispatching.
    ///
    /// The `userInfo` dictionary contains:
    /// - ``sessionIdUserInfoKey``: The new session ID (`String`)
    /// - ``previousSessionIdUserInfoKey``: The previous session ID (`String`), if any
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Set up observer before initializing the agent
    /// NotificationCenter.default.addObserver(
    ///     forName: Session.sessionIdDidChangeNotification,
    ///     object: nil,
    ///     queue: .main
    /// ) { notification in
    ///     let newSessionId = notification.userInfo?[Session.sessionIdUserInfoKey] as? String
    ///     let previousSessionId = notification.userInfo?[Session.previousSessionIdUserInfoKey] as? String
    ///     // Safe to update UI here
    /// }
    ///
    /// // Then initialize the agent
    /// let agent = try SplunkRum.install(with: configuration)
    /// ```
    ///
    /// - Important: To receive the notification for the initial session ID, register your observer
    ///   **before** calling ``SplunkRum/install(with:)``. The first session ID is set during
    ///   agent initialization.
    /// - Note: This notification is guaranteed to be delivered on the main thread.
    public static var sessionIdDidChangeNotification: Notification.Name {
        DefaultSession.sessionIdDidChangeNotification
    }

    /// Key for the new session ID in the ``sessionIdDidChangeNotification`` userInfo dictionary.
    ///
    /// The value associated with this key is a `String` containing the new session ID.
    public static var sessionIdUserInfoKey: String {
        DefaultSession.sessionIdUserInfoKey
    }

    /// Key for the previous session ID in the ``sessionIdDidChangeNotification`` userInfo dictionary.
    ///
    /// The value associated with this key is a `String` containing the previous session ID,
    /// or `nil` if this is the first session.
    public static var previousSessionIdUserInfoKey: String {
        DefaultSession.previousSessionIdUserInfoKey
    }


    // MARK: - State

    /// An object that reflects the current session's state, a ``SessionState`` instance.
    public private(set) lazy var state = SessionState(for: owner)


    // MARK: - Initialization

    init(for owner: SplunkRum) {
        self.owner = owner
    }
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
