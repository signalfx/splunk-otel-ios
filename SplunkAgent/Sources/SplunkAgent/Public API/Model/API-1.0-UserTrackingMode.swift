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

/// A mode of user tracking.
///
/// Determines whether and, if necessary, how the user will be tracked.
public enum UserTrackingMode: Codable, Equatable {

    /// No tracking. Individual user sessions are not linked in any way.
    ///
    /// This is a default option for user tracking.
    case noTracking

    /// Anonymous tracking. Allows you to link individual sessions
    /// under an anonymized user ID.
    ///
    /// - Note: An anonymous user ID is used, which cannot be traced
    /// to an individual for tracking across applications.
    case anonymousTracking
}


public extension UserTrackingMode {

    /// Default user tracking mode.
    static let `default`: UserTrackingMode = .noTracking
}
