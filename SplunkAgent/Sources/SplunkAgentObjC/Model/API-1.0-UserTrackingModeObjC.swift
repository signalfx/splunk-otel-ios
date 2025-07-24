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

/// A mode of user tracking.
///
/// Determines whether and, if necessary, how the user will be tracked.
@objc(SPLKUserTrackingMode)
public final class UserTrackingModeObjC: NSObject {

    // MARK: - Tracking modes

    /// No tracking. Individual user sessions are not linked in any way.
    ///
    /// This is a default option for user tracking.
    @objc
    public static let noTracking = NSNumber(value: 0)

    /// Anonymous tracking. Allows you to link individual sessions
    /// under an anonymized user ID.
    ///
    /// - Note: An anonymous user ID is used, which cannot be traced
    /// to an individual for tracking across applications.
    @objc
    public static let anonymousTracking = NSNumber(value: 1)


    // MARK: - Initialization

    // Initialization is hidden from the public API
    // as we only need to work with the class type.
    override init() {}


    // MARK: - Conversion utils

    static func userTrackingMode(for value: NSNumber) -> UserTrackingMode {
        switch value {
        case UserTrackingModeObjC.noTracking:
            return .noTracking

        case UserTrackingModeObjC.anonymousTracking:
            return .anonymousTracking

        default:
            return .default
        }
    }

    static func value(for userTrackingMode: UserTrackingMode) -> NSNumber {
        switch userTrackingMode {
        case .noTracking:
            return UserTrackingModeObjC.noTracking

        case .anonymousTracking:
            return UserTrackingModeObjC.anonymousTracking
        }
    }
}


@objc
public extension UserTrackingModeObjC {

    // MARK: - Default preset

    /// Default user tracking mode.
    @objc(defaultTracking)
    public static var `default` = value(for: UserTrackingMode.default)
}
