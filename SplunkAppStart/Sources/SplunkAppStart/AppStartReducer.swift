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

enum AppStartSuppressionReason: String, Equatable {
    case backgroundWithoutForeground
    case conflictingLifecycleEvidence
    case conflictingLaunchOrigin
    case invalidTimestampOrder
    case missingDidBecomeActive
    case missingForegroundBoundary
    case missingProcessStart
    case observationGap
    case unknownLaunchOrigin
}

/// The only AppStart state machine.
///
/// Reduction is pure and performs no I/O.
enum AppStartReducer {

    // MARK: - State

    enum State: Equatable {
        case initial(Evidence)
        case active(Resolution)
        case background(Resolution)
        case foregrounding(Resolution, Date)
        case stopped(Resolution)
    }

    enum Resolution: Equatable {
        /// An AppStart was emitted, so later complete activations are hot starts.
        case emitted

        /// The initial attempt was resolved without telemetry.
        case suppressed(AppStartSuppressionReason)

        /// The first activation was not observed, so its next completion must be dropped.
        case unobservedInitialActivation(AppStartSuppressionReason)

        /// The current activation became ambiguous and must be dropped at completion.
        case invalidActivation(AppStartSuppressionReason)

        var suppressionReason: AppStartSuppressionReason? {
            switch self {
            case .emitted:
                return nil

            case let .invalidActivation(reason),
                let .suppressed(reason),
                let .unobservedInitialActivation(reason):
                return reason
            }
        }

        var afterDiscardedActivation: Self {
            switch self {
            case let .invalidActivation(reason),
                let .unobservedInitialActivation(reason):
                return .suppressed(reason)

            case .emitted,
                .suppressed:
                return self
            }
        }

        var afterAbortedActivation: Self {
            switch self {
            case let .invalidActivation(reason):
                return .suppressed(reason)

            case .emitted,
                .suppressed,
                .unobservedInitialActivation:
                return self
            }
        }
    }

    enum LaunchOrigin: Equatable {
        case ambiguous
        case background
        case conflicting
        case foreground
        case foregroundResumed
        case prewarmed
        case unknown
    }

    enum ForegroundBoundary: Equatable {
        case hybrid(Date)
        case native(Date)

        var timestamp: Date {
            switch self {
            case let .hybrid(timestamp),
                let .native(timestamp):
                return timestamp
            }
        }

        var isNative: Bool {
            if case .native = self {
                return true
            }

            return false
        }
    }

    enum HybridHandoff: Equatable {
        case notReceived
        case received
    }

    struct Evidence: Equatable {
        var processStart: Date?
        var launchOrigin: LaunchOrigin
        var didFinishLaunching: Date?
        var foregroundBoundary: ForegroundBoundary?
        var didBecomeActive: Date?
        var hybridHandoff: HybridHandoff = .notReceived
    }


    // MARK: - Events and actions

    enum Event {
        case didFinishLaunching(Date, LaunchOrigin)
        case willEnterForeground(Date)
        case didBecomeActive(Date)
        case willResignActive
        case didEnterBackground
        case willTerminate
        case hybridSnapshot(AppStartLifecycleSnapshot, receivedAt: Date)
        case observationGap
    }

    enum Action {
        case send(AppStartSpanData)
        case suppress(AppStartSuppressionReason)
    }

    typealias Result = (state: State, action: Action?)


    // MARK: - Reduction

    static func reduce(state: State, event: Event) -> Result {
        switch state {
        case let .initial(evidence):
            return reduceInitial(evidence: evidence, event: event)

        case let .active(resolution):
            return reduceActive(resolution: resolution, event: event)

        case let .background(resolution):
            return reduceBackground(resolution: resolution, event: event)

        case let .foregrounding(resolution, start):
            return reduceForegrounding(
                resolution: resolution,
                start: start,
                event: event
            )

        case .stopped:
            return (state, nil)
        }
    }

    private static func reduceActive(
        resolution: Resolution,
        event: Event
    ) -> Result {
        switch event {
        case .didEnterBackground:
            return (.background(resolution), nil)

        case .willResignActive:
            return (.background(resolution), nil)

        case .observationGap:
            return (.background(resolution), nil)

        case .willTerminate:
            return (.stopped(resolution), nil)

        default:
            return (.active(resolution), nil)
        }
    }

    private static func reduceBackground(
        resolution: Resolution,
        event: Event
    ) -> Result {
        switch event {
        case let .willEnterForeground(timestamp):
            return (.foregrounding(resolution, timestamp), nil)

        case .didBecomeActive:
            return (.active(resolution.afterDiscardedActivation), nil)

        case .observationGap:
            return (.background(resolution), nil)

        case .willTerminate:
            return (.stopped(resolution), nil)

        default:
            return (.background(resolution), nil)
        }
    }

    private static func reduceForegrounding(
        resolution: Resolution,
        start: Date,
        event: Event
    ) -> Result {
        switch event {
        case let .didBecomeActive(end):
            return resolveHotStart(resolution: resolution, start: start, end: end)

        case let .willEnterForeground(timestamp):
            let reason = AppStartSuppressionReason.conflictingLifecycleEvidence
            return (
                .foregrounding(.invalidActivation(reason), timestamp),
                .suppress(reason)
            )

        case .didEnterBackground:
            return (.background(resolution.afterAbortedActivation), nil)

        case .willResignActive:
            return (.background(resolution.afterAbortedActivation), nil)

        case .observationGap:
            return (.background(resolution), nil)

        case .willTerminate:
            return (.stopped(resolution), nil)

        default:
            return (.foregrounding(resolution, start), nil)
        }
    }

    private static func resolveHotStart(
        resolution: Resolution,
        start: Date,
        end: Date
    ) -> Result {
        let resolvedInitial: Resolution

        switch resolution {
        case .invalidActivation:
            return (.active(resolution.afterDiscardedActivation), nil)

        case .unobservedInitialActivation(.observationGap):
            // A fresh foreground/active pair is a complete activation even if
            // the initial one was not observed. Keep the initial suppression
            // reason, but do not discard this independently bounded hot start.
            resolvedInitial = .suppressed(.observationGap)

        case .unobservedInitialActivation:
            return (.active(resolution.afterDiscardedActivation), nil)

        case .emitted,
            .suppressed:
            resolvedInitial = resolution
        }

        guard valid(start), valid(end), start <= end else {
            return (
                .active(resolvedInitial),
                .suppress(.invalidTimestampOrder)
            )
        }

        let span = AppStartSpanData(
            type: .hot,
            start: start,
            end: end,
            events: nil
        )

        return (.active(resolvedInitial), .send(span))
    }

    static func valid(_ timestamp: Date) -> Bool {
        let seconds = timestamp.timeIntervalSince1970
        let maximumSeconds = Double(UInt64.max) / 1_000_000_000

        return seconds.isFinite
            && seconds >= 0
            && seconds < maximumSeconds
    }
}
