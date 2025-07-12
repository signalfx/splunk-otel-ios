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

/// An object that represents the current user, providing access to their preferences and state.
public final class User {

    // MARK: - Internal

    // The SplunkRum instance that owns this user object.
    private unowned let owner: SplunkRum


    // MARK: - Public API

    /// An object for managing the user's preferences.
    ///
    /// See ``UserPreferences`` for more details.
    public private(set) lazy var preferences = UserPreferences(for: owner)

    /// An object that reflects the current state of the user.
    ///
    /// See ``UserState`` for more details.
    public private(set) lazy var state = UserState(for: owner)


    // MARK: - Initialization

    /// Initializes the user object with its owning `SplunkRum` instance.
    init(for owner: SplunkRum) {
        self.owner = owner
    }
}


extension User {

    // MARK: - Identifier

    /// The unique identifier for the current user.
    var identifier: String {
        owner.currentUser.userIdentifier
    }
}