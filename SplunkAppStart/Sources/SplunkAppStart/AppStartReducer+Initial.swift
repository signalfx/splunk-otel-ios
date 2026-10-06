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

extension AppStartReducer {

    // MARK: - Initial reduction

    static func reduceInitial(
        evidence: Evidence,
        event: Event
    ) -> Result {
        switch event {
        case let .didFinishLaunching(timestamp, launchOrigin):
            return resolve(
                evidence.recordingLaunch(
                    timestamp,
                    launchOrigin: launchOrigin
                )
            )

        case let .willEnterForeground(timestamp):
            return reduceInitialForeground(evidence: evidence, timestamp: timestamp)

        case let .didBecomeActive(timestamp):
            return resolve(evidence.recordingActivation(timestamp))

        case .willResignActive:
            switch evidence.launchOrigin {
            case .background,
                .foreground,
                .foregroundResumed,
                .prewarmed:
                // Resigning active is not proof that the app entered the background.
                // Preserve known launch evidence until didEnterBackground confirms
                // that the initial activation was interrupted.
                return (.initial(evidence), nil)

            case .ambiguous,
                .conflicting,
                .unknown:
                return suppressInitial(evidence, nextState: State.background)
            }

        case .didEnterBackground:
            return reduceInitialBackground(evidence)

        case .willTerminate:
            return suppressInitial(evidence, nextState: State.stopped)

        case let .hybridSnapshot(snapshot, receivedAt):
            return reduceInitialHybrid(
                evidence: evidence,
                snapshot: snapshot,
                receivedAt: receivedAt
            )

        case .observationGap:
            return (
                .background(.unobservedInitialActivation(.observationGap)),
                .suppress(.observationGap)
            )
        }
    }

    private static func reduceInitialHybrid(
        evidence: Evidence,
        snapshot: AppStartLifecycleSnapshot,
        receivedAt: Date
    ) -> Result {
        guard evidence.hybridHandoff == .notReceived else {
            return suppressed(.conflictingLifecycleEvidence)
        }

        guard validHybridSnapshot(snapshot, receivedAt: receivedAt) else {
            return suppressed(.invalidTimestampOrder)
        }

        return resolve(evidence.merging(snapshot))
    }

    private static func reduceInitialForeground(
        evidence: Evidence,
        timestamp: Date
    ) -> Result {
        guard !evidence.hasNativeForegroundBoundary else {
            let reason = AppStartSuppressionReason.conflictingLifecycleEvidence
            return (
                .foregrounding(.unobservedInitialActivation(reason), timestamp),
                .suppress(reason)
            )
        }

        guard evidence.didBecomeActive == nil else {
            let reason = suppressionReason(for: evidence)
            return (
                .foregrounding(.unobservedInitialActivation(reason), timestamp),
                .suppress(reason)
            )
        }

        return resolve(evidence.recordingForeground(timestamp))
    }

    private static func reduceInitialBackground(_ evidence: Evidence) -> Result {
        guard evidence.didBecomeActive == nil else {
            return suppressInitial(evidence, nextState: State.background)
        }

        guard evidence.launchOrigin != .unknown,
            evidence.launchOrigin != .ambiguous
        else {
            let reason = suppressionReason(for: evidence)
            return (
                .background(.unobservedInitialActivation(reason)),
                .suppress(reason)
            )
        }

        return resolve(evidence.recordingBackground())
    }


    // MARK: - Initial resolution

    private static func resolve(_ evidence: Evidence) -> Result {
        guard let end = evidence.didBecomeActive else {
            return (.initial(evidence), nil)
        }

        guard evidence.hasValidTimestamps else {
            return suppressed(.invalidTimestampOrder)
        }

        switch evidence.launchOrigin {
        case .ambiguous:
            return suppressed(.unknownLaunchOrigin)

        case .foreground:
            return resolveColdStart(evidence, end: end)

        case .foregroundResumed:
            return resolveWarmStart(evidence, end: end)

        case .background:
            return resolveWarmStart(evidence, end: end)

        case .prewarmed:
            return resolveWarmStart(evidence, end: end)

        case .conflicting:
            return suppressed(.conflictingLaunchOrigin)

        case .unknown:
            return (.initial(evidence), nil)
        }
    }

    private static func resolveColdStart(
        _ evidence: Evidence,
        end: Date
    ) -> Result {
        guard evidence.willEnterForeground == nil else {
            return suppressed(.conflictingLaunchOrigin)
        }

        guard let start = evidence.processStart else {
            return suppressed(.missingProcessStart)
        }

        return emit(
            type: .cold,
            start: start,
            end: end,
            events: evidence.coldEvents
        )
    }

    private static func resolveWarmStart(
        _ evidence: Evidence,
        end: Date
    ) -> Result {
        guard let start = evidence.willEnterForeground else {
            return suppressed(.missingForegroundBoundary)
        }

        return emit(type: .warm, start: start, end: end, events: nil)
    }

    private static func emit(
        type: AppStartType,
        start: Date,
        end: Date,
        events: [AppStartEvent]?
    ) -> Result {
        switch validatedSpan(
            type: type,
            start: start,
            end: end,
            events: events
        ) {
        case let .success(span):
            return (.active(.emitted), .send(span))

        case let .failure(reason):
            return suppressed(reason)
        }
    }

    private static func suppressInitial(
        _ evidence: Evidence,
        nextState: (Resolution) -> State
    ) -> Result {
        let reason = suppressionReason(for: evidence)
        return (nextState(.suppressed(reason)), .suppress(reason))
    }

    private static func suppressed(_ reason: AppStartSuppressionReason) -> Result {
        (.active(.suppressed(reason)), .suppress(reason))
    }

    private static func validHybridSnapshot(
        _ snapshot: AppStartLifecycleSnapshot,
        receivedAt: Date
    ) -> Bool {
        guard valid(receivedAt) else {
            return false
        }

        return [
            snapshot.didFinishLaunching,
            snapshot.willEnterForeground,
            snapshot.didBecomeActive
        ]
        .compactMap(\.self)
        .allSatisfy { valid($0) && $0 <= receivedAt }
    }

    private static func suppressionReason(
        for evidence: Evidence
    ) -> AppStartSuppressionReason {
        guard evidence.hasValidTimestamps else {
            return .invalidTimestampOrder
        }

        switch evidence.launchOrigin {
        case .ambiguous:
            return .unknownLaunchOrigin

        case .background:
            return evidence.willEnterForeground == nil
                ? .backgroundWithoutForeground
                : .missingDidBecomeActive

        case .prewarmed:
            return evidence.willEnterForeground == nil
                ? .backgroundWithoutForeground
                : .missingDidBecomeActive

        case .conflicting:
            return .conflictingLaunchOrigin

        case .foreground:
            return .missingDidBecomeActive

        case .foregroundResumed:
            return evidence.willEnterForeground == nil
                ? .backgroundWithoutForeground
                : .missingDidBecomeActive

        case .unknown:
            return .unknownLaunchOrigin
        }
    }
}
