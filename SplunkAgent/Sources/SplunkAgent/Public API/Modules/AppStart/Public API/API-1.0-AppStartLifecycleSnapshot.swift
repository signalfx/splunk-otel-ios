//
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
///
/// The foreground and active timestamps must belong to the same activation in the
/// current process. If a foreground launch is interrupted by a background transition,
/// use ``LaunchOrigin/foregroundResumed`` and replace the interrupted foreground
/// timestamp with the boundary paired with the supplied activation. Submit exactly one
/// snapshot immediately after agent installation; a pre-install handoff is discarded.
public struct AppStartLifecycleSnapshot {

    // MARK: - Launch origin

    /// Describes the known launch and initial-activation provenance.
    public enum LaunchOrigin: Equatable {
        /// The process was launched for a user-visible foreground activation.
        case foreground

        /// The process was launched to perform background work.
        case background

        /// A foreground process launch was interrupted by a background transition,
        /// and the supplied activation resumed from that background state.
        case foregroundResumed

        /// The launch origin could not be determined reliably.
        case unknown
    }


    // MARK: - Public

    /// The observed launch and initial-activation provenance.
    public let launchOrigin: LaunchOrigin

    /// The first `UIApplication.didFinishLaunchingNotification` timestamp, when observed.
    public let didFinishLaunching: Date?

    /// The `UIApplication.willEnterForegroundNotification` boundary paired with
    /// `didBecomeActive`, when the process launched in the background.
    public let willEnterForeground: Date?

    /// The first `UIApplication.didBecomeActiveNotification` timestamp, when observed.
    public let didBecomeActive: Date?


    // MARK: - Initialization

    /// Creates initial lifecycle evidence captured before SDK installation.
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
public typealias AppStartLaunchOrigin = AppStartLifecycleSnapshot.LaunchOrigin
