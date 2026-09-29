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
@_spi(SplunkInternal) import SplunkCommon

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

    /// How strongly the launch origin is supported by lifecycle evidence.
    public let launchOriginConfidence: AppLifecycleRecorder.LaunchOriginConfidence

    /// The captured `UIApplication.didFinishLaunchingNotification` timestamp.
    public let didFinishLaunching: Date?

    /// The captured `UIApplication.willEnterForegroundNotification` timestamp.
    public let willEnterForeground: Date?

    /// The captured `UIApplication.didBecomeActiveNotification` timestamp.
    public let didBecomeActive: Date?

    /// The time at which the core recorder started observing lifecycle events.
    public let recorderStartedAt: Date?

    /// Whether the process exposed Apple's prewarm marker to the recorder.
    public let prewarmDetected: Bool

    /// The bounded ordered lifecycle history captured before SDK installation.
    public let events: [AppLifecycleRecorder.EventRecord]

    /// Creates lifecycle evidence for initial AppStart classification.
    public init(
        launchOrigin: LaunchOrigin,
        launchOriginConfidence: AppLifecycleRecorder.LaunchOriginConfidence = .unknown,
        didFinishLaunching: Date?,
        willEnterForeground: Date?,
        didBecomeActive: Date?,
        recorderStartedAt: Date? = nil,
        prewarmDetected: Bool = false,
        events: [AppLifecycleRecorder.EventRecord] = []
    ) {
        self.launchOrigin = launchOrigin
        self.launchOriginConfidence = launchOriginConfidence
        self.didFinishLaunching = didFinishLaunching
        self.willEnterForeground = willEnterForeground
        self.didBecomeActive = didBecomeActive
        self.recorderStartedAt = recorderStartedAt
        self.prewarmDetected = prewarmDetected
        self.events = events
    }
}

/// Convenience name for the launch-origin type used by hybrid integrations.
@_spi(SplunkInternal)
public typealias AppStartLaunchOrigin = AppStartLifecycleSnapshot.LaunchOrigin
