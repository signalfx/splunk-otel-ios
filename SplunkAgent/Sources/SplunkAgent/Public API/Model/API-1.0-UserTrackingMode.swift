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

/// An enumeration that defines how the user is tracked and identified.
///
/// You can set this mode in the ``UserConfiguration`` to control user privacy.
///
/// ### Example ###
/// ```
/// var config = UserConfiguration()
/// config.trackingMode = .anonymousTracking
/// ```
public enum UserTrackingMode: Codable, Equatable {

    /// Disables user tracking.
    ///
    /// When this mode is active, individual user sessions are not linked together.
    case noTracking

    /// Enables anonymous user tracking.
    ///
    /// This mode links individual sessions together under a single, anonymized user ID.
    ///
    /// - Note: The anonymous user ID is generated locally and cannot be used to
    ///         identify the user across different applications or devices.
    case anonymousTracking
}


public extension UserTrackingMode {

    /// The default user tracking mode, which is ``noTracking``.
    static let `default`: UserTrackingMode = .noTracking
}