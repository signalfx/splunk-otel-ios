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

/// A configuration for user-related settings, such as the user tracking mode.
public struct UserConfiguration: Codable, Equatable {

    // MARK: - Public properties

    /// The mode for tracking and identifying the user.
    ///
    /// Defaults to `.default`. See ``UserTrackingMode`` for all available options.
    public var trackingMode: UserTrackingMode = .default


    // MARK: - Initialization

    /// Initializes the user configuration with default values.
    public init() {}

    /// Initializes the user configuration with a specific tracking mode.
    ///
    /// - Parameter trackingMode: The preferred ``UserTrackingMode``.
    ///
    /// ### Example ###
    /// ```
    /// // Configure user tracking to be anonymous
    /// let userConfig = UserConfiguration(trackingMode: .anonymous)
    /// ```
    public init(trackingMode: UserTrackingMode) {
        self.trackingMode = trackingMode
    }
}