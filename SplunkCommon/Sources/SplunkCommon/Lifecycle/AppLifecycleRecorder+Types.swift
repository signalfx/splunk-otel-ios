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

#if canImport(UIKit)
    import UIKit
#endif

@_spi(SplunkInternal)
extension AppLifecycleRecorder {

    // MARK: - Public types

    /// The best-known origin of the initial process launch.
    @_spi(SplunkInternal)
    public enum LaunchOrigin: Equatable {
        /// The process was launched for a user-visible foreground activation.
        case foreground

        /// The process was launched to perform background work.
        case background

        /// The launch origin could not be determined reliably.
        case unknown
    }

    /// Describes how strongly the recorder can support its launch-origin claim.
    @_spi(SplunkInternal)
    public enum LaunchOriginConfidence: Equatable {
        /// The origin follows an explicit application-state/lifecycle sequence.
        case observed

        /// The origin was inferred from elapsed time because OS evidence was incomplete.
        /// Inferred provenance must not bypass duration corruption guards.
        case inferred

        /// There is not enough evidence to classify the launch.
        case unknown
    }

    /// The lifecycle event kind stored in the ordered history.
    @_spi(SplunkInternal)
    public enum EventKind: Equatable {
        case didFinishLaunching
        case willEnterForeground
        case didBecomeActive
        case willResignActive
        case didEnterBackground
        case willTerminate
    }

    /// The application state observed when a lifecycle event was recorded.
    @_spi(SplunkInternal)
    public enum ApplicationState: Equatable {
        case active
        case inactive
        case background
        case unknown
    }

    /// The source that produced a lifecycle record.
    @_spi(SplunkInternal)
    public enum EventSource: Equatable {
        case notification
    }

    /// A lifecycle event delivered to subscribers.
    @_spi(SplunkInternal)
    public enum Event {
        /// The application finished launching.
        case didFinishLaunching(Date)

        /// The application is moving from background to foreground.
        case willEnterForeground(Date)

        /// The application became active.
        case didBecomeActive(Date)

        /// The application is moving from active to inactive.
        case willResignActive(Date)

        /// The application entered the background.
        case didEnterBackground(Date)

        /// The application is about to terminate.
        case willTerminate(Date)
    }

    /// A timestamped, ordered lifecycle record.
    @_spi(SplunkInternal)
    public struct EventRecord: Equatable {
        public let kind: EventKind
        public let timestamp: Date
        public let applicationState: ApplicationState
        public let launchOptionKeys: [String]
        public let sequence: UInt64
        public let source: EventSource

        init(
            kind: EventKind,
            timestamp: Date,
            applicationState: ApplicationState,
            launchOptionKeys: [String] = [],
            sequence: UInt64,
            source: EventSource
        ) {
            self.kind = kind
            self.timestamp = timestamp
            self.applicationState = applicationState
            self.launchOptionKeys = launchOptionKeys
            self.sequence = sequence
            self.source = source
        }

        /// The legacy event representation used by lifecycle consumers.
        public var event: Event {
            switch kind {
            case .didFinishLaunching:
                return .didFinishLaunching(timestamp)

            case .willEnterForeground:
                return .willEnterForeground(timestamp)

            case .didBecomeActive:
                return .didBecomeActive(timestamp)

            case .willResignActive:
                return .willResignActive(timestamp)

            case .didEnterBackground:
                return .didEnterBackground(timestamp)

            case .willTerminate:
                return .willTerminate(timestamp)
            }
        }
    }

    /// The first-launch evidence currently known by the recorder.
    @_spi(SplunkInternal)
    public struct Snapshot {
        /// The time at which this recorder started observing lifecycle events.
        public let recorderStartedAt: Date
        /// Whether the process exposed Apple's prewarm marker to the recorder.
        public let prewarmDetected: Bool
        public let launchOrigin: LaunchOrigin
        public let launchOriginConfidence: LaunchOriginConfidence
        public let didFinishLaunching: Date?
        public let willEnterForeground: Date?
        public let didBecomeActive: Date?
        /// Bounded lifecycle history in notification order.
        public let events: [EventRecord]
    }

    /// An update containing the latest snapshot and the event that caused it.
    @_spi(SplunkInternal)
    public struct Update {
        public let event: Event?
        public let eventRecord: EventRecord?
        public let snapshot: Snapshot
    }
}
