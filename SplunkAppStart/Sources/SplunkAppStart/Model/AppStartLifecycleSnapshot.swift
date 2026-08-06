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

/// An immutable snapshot of initial application lifecycle evidence captured by a hybrid agent.
public struct AppStartLifecycleSnapshot {

    // MARK: - Inline types

    /// Describes whether the initial process launch was caused by a foreground or background event.
    public enum LaunchOrigin {

        /// The process was launched for a user-visible foreground activation.
        case foreground

        /// The process was launched to perform background work.
        case background

        /// The launch origin could not be determined by the early lifecycle observer.
        case unknown
    }


    // MARK: - Public

    /// Whether the process was initially launched for foreground or background execution.
    public let launchOrigin: LaunchOrigin

    /// The captured `UIApplication.didFinishLaunchingNotification` timestamp, if observed.
    public let didFinishLaunching: Date?

    /// The captured `UIApplication.willEnterForegroundNotification` timestamp, if observed.
    public let willEnterForeground: Date?

    /// The captured `UIApplication.didBecomeActiveNotification` timestamp, if observed.
    public let didBecomeActive: Date?


    // MARK: - Initialization

    /// Creates an immutable initial lifecycle snapshot.
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

/// Compatibility name for the launch-origin type used by existing hybrid integrations.
public typealias AppStartLaunchOrigin = AppStartLifecycleSnapshot.LaunchOrigin
