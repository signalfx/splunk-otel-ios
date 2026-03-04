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
import SplunkAgent

/// A session object is a representation of the current user session.
@objc(SPLKSession)
public final class SessionObjC: NSObject {

    // MARK: - Internal

    private unowned let owner: SplunkRumObjC


    // MARK: - Notifications

    /// A notification that posts whenever a session ID is set or changed.
    ///
    /// This notification is always posted on the **main thread**, making it safe to update
    /// UI directly from the observer without additional dispatching.
    ///
    /// The `userInfo` dictionary contains:
    /// - ``sessionIdUserInfoKey``: The new session ID (`NSString`)
    /// - ``previousSessionIdUserInfoKey``: The previous session ID (`NSString`), if any
    ///
    /// - Important: To receive the notification for the initial session ID, register your observer
    ///   **before** calling `-[SPLKAgent installWith:error:]`. The first session ID is set during
    ///   agent initialization.
    /// - Note: This notification is guaranteed to be delivered on the main thread.
    @objc
    public static let sessionIdDidChangeNotification: NSNotification.Name = Session.sessionIdDidChangeNotification

    /// Key for the new session ID in the ``sessionIdDidChangeNotification`` userInfo dictionary.
    ///
    /// The value associated with this key is an `NSString` containing the new session ID.
    @objc
    public static let sessionIdUserInfoKey: String = Session.sessionIdUserInfoKey

    /// Key for the previous session ID in the ``sessionIdDidChangeNotification`` userInfo dictionary.
    ///
    /// The value associated with this key is an `NSString` containing the previous session ID,
    /// or `nil` if this is the first session.
    @objc
    public static let previousSessionIdUserInfoKey: String = Session.previousSessionIdUserInfoKey


    // MARK: - Public API

    /// An object that reflects the current session's state.
    @objc
    public private(set) lazy var state = SessionStateObjC(for: owner)


    // MARK: - Initialization

    init(for owner: SplunkRumObjC) {
        self.owner = owner
    }
}
