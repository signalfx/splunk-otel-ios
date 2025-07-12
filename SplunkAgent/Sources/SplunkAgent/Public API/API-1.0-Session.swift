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

/// An object that represents the current user session.
///
/// This class provides access to the session identifier and its current state.
public final class Session {

    // MARK: - Internal

    // The SplunkRum instance that owns this session.
    private unowned let owner: SplunkRum


    // MARK: - State

    /// An object that reflects the current state of the session.
    ///
    /// See ``SessionState`` for more details.
    public private(set) lazy var state = SessionState(for: owner)


    // MARK: - Initialization

    /// Initializes the session with its owning `SplunkRum` instance.
    init(for owner: SplunkRum) {
        self.owner = owner
    }
}


public extension Session {

    // MARK: - Identifier

    /// Returns the session identifier for a specific point in time.
    ///
    /// Some events can be tracked with a delay caused by, e.g., its asynchronous pre-processing
    /// or an application crash. This method returns the correct session ID for the timestamp when the event originated.
    ///
    /// - Parameter timestamp: The `Date` for which to retrieve the session ID.
    /// - Returns: The session ID as a `String`, or `nil` if no session exists at that time.
    func sessionId(for timestamp: Date) -> String? {
        owner.currentSession.sessionId(for: timestamp)
    }
}