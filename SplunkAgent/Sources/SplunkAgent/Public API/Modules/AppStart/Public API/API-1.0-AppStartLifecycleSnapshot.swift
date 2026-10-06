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
/// React Native and Flutter keep the lightweight, platform-specific early observer
/// they already load before the agent. The observer captures evidence only; the iOS
/// AppStart reducer owns timestamp validation, classification, suppression, and span
/// creation after installation. No core load-time constructor is required.
///
/// Use the following native lifecycle contract in every hybrid adapter:
///
/// | Launch origin | Launch event | Events before first activation |
/// | --- | --- | --- |
/// | `foreground` | `didFinishLaunching` | `didBecomeActive` |
/// | `background` | `didFinishLaunching` | `willEnterForeground` → `didBecomeActive` |
/// | `foregroundResumed` | `didFinishLaunching` | `willResignActive` → `didEnterBackground` → `willEnterForeground` → `didBecomeActive` |
/// | `unknown` | Incomplete or contradictory | Supply only observed events; native resolution fails closed. |
///
/// The foreground and active timestamps must belong to the same activation in the
/// current process. If a foreground launch is interrupted by a background transition,
/// use ``LaunchOrigin/foregroundResumed`` and replace the interrupted foreground
/// timestamp with the boundary paired with the supplied activation. Submit exactly one
/// snapshot immediately after agent installation, even if that snapshot is partial.
/// A pre-install handoff is discarded. If installation occurs between
/// `willEnterForeground` and `didBecomeActive`, the native observer completes the pending
/// pair. If the app backgrounds first, that pending boundary is discarded.
/// Before emission, the iOS AppStart reducer applies the same five-second maximum to the
/// final cold, warm, or hot span boundary. A longer measurement is suppressed rather
/// than clamped or emitted with an implausible duration.
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
    /// `didBecomeActive`, when the process launched in the background or resumed
    /// after its initial foreground activation was interrupted.
    public let willEnterForeground: Date?

    /// The first `UIApplication.didBecomeActiveNotification` timestamp, when observed.
    ///
    /// Leave this `nil` when the handoff occurs before activation; the native observer
    /// will complete the pending measurement.
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
