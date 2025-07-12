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

/// A configuration for session-related settings, such as the session sampling rate.
public struct SessionConfiguration: Codable, Equatable {

    // MARK: - Public properties

    /// The session sampling rate, controlling what percentage of sessions are recorded.
    ///
    /// This value must be in the range `0.0` to `1.0`.
    /// - `1.0` means 100% of sessions are recorded.
    /// - `0.5` means 50% of sessions are recorded.
    /// - `0.0` means 0% of sessions are recorded.
    ///
    /// Defaults to `1.0`.
    public var samplingRate = ConfigurationDefaults.sessionSamplingRate


    // MARK: - Initialization

    /// Initializes the session configuration with default values.
    public init() {}

    /// Initializes the session configuration with a custom sampling rate.
    ///
    /// - Parameter samplingRate: The session sampling rate, a value between `0.0` and `1.0`.
    ///
    /// ### Example ###
    /// ```
    /// // Record 25% of all user sessions
    /// let sessionConfig = SessionConfiguration(samplingRate: 0.25)
    /// ```
    public init(samplingRate: Double) {
        self.samplingRate = samplingRate
    }
}