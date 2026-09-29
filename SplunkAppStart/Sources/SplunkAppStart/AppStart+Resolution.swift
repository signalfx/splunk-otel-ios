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

internal import CiscoLogger
@_spi(SplunkInternal) import SplunkCommon
import UIKit

extension AppStart {

    // MARK: - Sending

    /// Sends results into a destination.
    func send(start: Date, end: Date, type: AppStartType) {

        var events: [AppStartEvent]?
        var initializeData: AgentInitializeSpanData?

        // Send app start events and initialize span in a cold start only
        if type == .cold {
            events = coldStartEvents(startTime: start)
            initializeData = agentInitializeSpanData

            coldStartSent = true
        }

        let appStartData = AppStartSpanData(
            type: type,
            start: start,
            end: end,
            events: events
        )

        destination.send(appStart: appStartData, agentInitialize: initializeData, sharedState: sharedState)
    }

    // MARK: - Resolution

    func merge(initialLifecycle snapshot: AppStartLifecycleSnapshot, acceptUnknownOrigin: Bool = true) {
        didFinishLaunchingTimestamp = didFinishLaunchingTimestamp ?? snapshot.didFinishLaunching
        willEnterForegroundTimestamp = willEnterForegroundTimestamp ?? snapshot.willEnterForeground
        didBecomeActiveTimestamp = didBecomeActiveTimestamp ?? snapshot.didBecomeActive
        prewarmDetected = prewarmDetected || snapshot.prewarmDetected

        // Replay the same ordered evidence used by AppState. The scalar fields
        // above preserve compatibility with integrations that only provide three
        // timestamps, while the history fills in transitions such as
        // willResignActive and willTerminate that are otherwise lost on handoff.
        for record in snapshot.events {
            mergeCoreLifecycleEvent(record.event)
        }

        if acceptUnknownOrigin || snapshot.launchOrigin != .unknown {
            let incomingConfidenceRank = launchOriginConfidenceRank(snapshot.launchOriginConfidence)
            let capturedConfidenceRank = launchOriginConfidenceRank(capturedLaunchOriginConfidence)

            if capturedLaunchOrigin == nil || capturedLaunchOrigin == .unknown
                || incomingConfidenceRank > capturedConfidenceRank
            {
                capturedLaunchOrigin = snapshot.launchOrigin
                capturedLaunchOriginConfidence = snapshot.launchOriginConfidence
            }
        }
    }

    func launchOriginConfidenceRank(
        _ confidence: AppLifecycleRecorder.LaunchOriginConfidence
    ) -> Int {
        switch confidence {
        case .unknown:
            return 0

        case .inferred:
            return 1

        case .observed:
            return 2
        }
    }

    func processCoreLifecycleEvent(_ event: AppLifecycleRecorder.Event, resolve: Bool = true) {
        if case .suppressed = initialAppStartState,
            case .willResignActive = event
        {
            // The initial suppression may have retained an earlier foreground
            // boundary. Start a fresh boundary pair for the next hot start.
            willEnterForegroundTimestamp = nil
            willResignActiveTimestamp = nil
            didBecomeActiveTimestamp = nil
        }

        mergeCoreLifecycleEvent(event)

        if resolve {
            switch event {
            case .didBecomeActive:
                determineAndSend()

            case .willTerminate:
                if !initialAppStartState.isTerminal {
                    suppressInitialAppStart(reason: suppressionReason())
                }

            default:
                break
            }
        }
    }

    func mergeCoreLifecycleEvent(_ event: AppLifecycleRecorder.Event) {
        switch event {
        case let .didFinishLaunching(timestamp):
            didFinishLaunchingTimestamp = didFinishLaunchingTimestamp ?? timestamp

        case let .willEnterForeground(timestamp):
            willEnterForegroundTimestamp = willEnterForegroundTimestamp ?? timestamp

        case let .didBecomeActive(timestamp):
            didBecomeActiveTimestamp = didBecomeActiveTimestamp ?? timestamp

        case let .willResignActive(timestamp):
            willResignActiveTimestamp = willResignActiveTimestamp ?? timestamp

        case .didEnterBackground,
            .willTerminate:
            break
        }
    }

    func scheduleInitialHandoffTimeout() {
        guard initialHandoffTimeoutWorkItem == nil,
            !initialAppStartState.isTerminal,
            !isWaitingForBackgroundForegroundBoundary
        else {
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, !initialAppStartState.isTerminal else {
                return
            }

            initialHandoffTimeoutWorkItem = nil

            if isWaitingForBackgroundForegroundBoundary {
                return
            }

            if didBecomeActiveTimestamp == nil {
                suppressInitialAppStart(reason: .missingDidBecomeActive)
            }
            else {
                determineAndSend()
            }
        }

        initialHandoffTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + initialHandoffTimeout,
            execute: workItem
        )
    }

    func cancelInitialHandoffTimeout() {
        initialHandoffTimeoutWorkItem?.cancel()
        initialHandoffTimeoutWorkItem = nil
    }

    func resolveInitialAppStart(as state: AppStartResolutionState) {
        guard !initialAppStartState.isTerminal else {
            return
        }

        initialAppStartState = state
        cancelInitialHandoffTimeout()
    }

    func suppressInitialAppStart(reason: AppStartSuppressionReason) {
        guard !initialAppStartState.isTerminal else {
            return
        }

        resolveInitialAppStart(as: .suppressed(reason))
        suppressionCounts[reason, default: 0] += 1

        logger.log(level: .warn) {
            "AppStart measurement suppressed. reason=\(reason.rawValue)"
        }
    }

    func suppressionReason() -> AppStartSuppressionReason {
        if isWaitingForBackgroundForegroundBoundary {
            return .backgroundWithoutForeground
        }

        guard didBecomeActiveTimestamp != nil else {
            return .missingDidBecomeActive
        }

        guard let didBecomeActiveTimestamp,
            validSnapshotEventTimes(end: didBecomeActiveTimestamp)
        else {
            return .invalidTimestampOrder
        }

        if let capturedLaunchOrigin {
            switch capturedLaunchOrigin {
            case .background:
                return willEnterForegroundTimestamp == nil ? .missingForegroundBoundary : .unknownLaunchOrigin

            case .unknown:
                return .unknownLaunchOrigin

            case .foreground:
                return processStartTimestamp == nil ? .missingProcessStart : .unknownLaunchOrigin
            }
        }

        if backgroundLaunchDetected == nil {
            return .unknownLaunchOrigin
        }

        return .unknownLaunchOrigin
    }

    var isWaitingForBackgroundForegroundBoundary: Bool {
        capturedLaunchOrigin == .background
            && capturedLaunchOriginConfidence == .observed
            && willEnterForegroundTimestamp == nil
    }
}
