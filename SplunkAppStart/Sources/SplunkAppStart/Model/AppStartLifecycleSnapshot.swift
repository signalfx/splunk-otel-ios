/*
Copyright 2026 Splunk Inc.

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

/// Lifecycle evidence captured by a hybrid integration before the iOS SDK is installed.
@_spi(SplunkInternal)
public struct AppStartLifecycleSnapshot {

    /// Describes the known origin of the initial process launch.
    public enum LaunchOrigin {
        /// The process was launched for a user-visible foreground activation.
        case foreground

        /// The process was launched to perform background work.
        case background

        /// The launch origin could not be determined reliably.
        case unknown
    }

    /// The observed launch origin.
    public let launchOrigin: LaunchOrigin

    /// The captured `UIApplication.didFinishLaunchingNotification` timestamp.
    public let didFinishLaunching: Date?

    /// The captured `UIApplication.willEnterForegroundNotification` timestamp.
    public let willEnterForeground: Date?

    /// The captured `UIApplication.didBecomeActiveNotification` timestamp.
    public let didBecomeActive: Date?

    /// Creates lifecycle evidence for initial AppStart classification.
    public init(
        launchOrigin: LaunchOrigin,
        didFinishLaunching: Date?,
        willEnterForeground: Date?,
        didBecomeActive: Date?
    ) {
        self.launchOrigin = launchOrigin
        self.didFinishLaunching = didFinishLaunching
        self.willEnterForeground = willEnterForeground
        self.didBecomeActive = didBecomeActive
    }
}

/// Convenience name for the launch-origin type used by hybrid integrations.
@_spi(SplunkInternal)
public typealias AppStartLaunchOrigin = AppStartLifecycleSnapshot.LaunchOrigin
