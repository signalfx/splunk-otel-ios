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

    // MARK: - Type determination

    /// Determines an app start type and sends valid results.
    func determineAndSend() {
        guard !shouldIgnoreLifecycleResolution,
            !awaitingObservedBackgroundHandoff,
            !isWaitingForBackgroundForegroundBoundary
        else {
            return
        }

        defer {
            resetAppStartResolutionState()
        }

        guard let endTime = didBecomeActiveTimestamp else {
            logger.log(level: .debug) {
                "Cannot determine app start without a didBecomeActive timestamp."
            }
            return
        }

        if let (determinedType, startTime) = determinedAppStartType() {
            sendIfValid(start: startTime, end: endTime, type: determinedType)
        }
        else {
            suppressInitialAppStart(reason: suppressionReason())
        }
    }

    private var shouldIgnoreLifecycleResolution: Bool {
        guard case .suppressed = initialAppStartState else {
            return false
        }

        return willResignActiveTimestamp == nil || willEnterForegroundTimestamp == nil
    }

    private func resetAppStartResolutionState() {
        didFinishLaunchingTimestamp = nil
        willEnterForegroundTimestamp = nil
        willResignActiveTimestamp = nil
        didBecomeActiveTimestamp = nil
        capturedLaunchOrigin = nil
        capturedLaunchOriginConfidence = .unknown
        backgroundLaunchConfidence = .unknown

        // Initialization data is sent only once with the cold start.
        agentInitializeSpanData = nil
    }

    private func sendIfValid(start: Date, end: Date, type: AppStartType) {
        guard start.timeIntervalSinceReferenceDate.isFinite,
            end.timeIntervalSinceReferenceDate.isFinite,
            start <= end
        else {
            suppressInitialAppStart(reason: .invalidTimestampOrder)
            return
        }

        let duration = end.timeIntervalSince(start)
        let provenanceIsTrusted = capturedLaunchOriginConfidence == .observed

        guard duration.isFinite,
            provenanceIsTrusted || duration <= maxAppStartDuration
        else {
            suppressInitialAppStart(reason: .maxDurationExceeded)
            return
        }

        // Resolve before handing data to the destination so a synchronous
        // callback cannot re-enter the resolver and emit a duplicate.
        resolveInitialAppStart(as: .emitted)
        send(start: start, end: end, type: type)

        logger.log(level: .debug) {
            "App start log: determined app start type: \(type.rawValue), start time: \(start), end time: \(end)."
        }
    }

    /// Determines app start type from available notifications timestamps.
    func determinedAppStartType() -> (AppStartType, Date)? {
        guard let didBecomeActiveTimestamp else {
            return nil
        }

        if let willResignActiveTimestamp,
            let willEnterForegroundTimestamp,
            willResignActiveTimestamp <= willEnterForegroundTimestamp
        {
            return (.hot, willEnterForegroundTimestamp)
        }

        // Prewarm means that process start is not a valid user-visible cold-start anchor.
        // Check it before hybrid launch origin because UIApplication may report .active or
        // .inactive for a prewarmed process when the early hybrid observer runs.
        if prewarmDetected,
            let startTime = willEnterForegroundTimestamp,
            startTime <= didBecomeActiveTimestamp
        {
            return (.warm, startTime)
        }

        if let capturedLaunchOrigin {
            return determinedSnapshotAppStartType(launchOrigin: capturedLaunchOrigin)
        }

        let launchedInBackground = backgroundLaunchDetected

        // A timing-only background inference is deliberately not a customer-visible
        // warm start. A long splash screen can produce the same delay, so the
        // conservative outcome is suppression rather than misclassification.
        if launchedInBackground == true,
            backgroundLaunchConfidence == .inferred
        {
            return nil
        }

        if !initialAppStartState.isTerminal,
            launchedInBackground == true || prewarmDetected,
            let startTime = willEnterForegroundTimestamp
        {
            return (.warm, startTime)
        }

        if !initialAppStartState.isTerminal, !coldStartSent, let startTime = processStartTimestamp {
            if launchedInBackground == nil {
                guard let didFinishLaunchingTimestamp,
                    let willEnterForegroundTimestamp,
                    willEnterForegroundTimestamp >= didFinishLaunchingTimestamp
                else {
                    return nil
                }

                if willEnterForegroundTimestamp.timeIntervalSince(didFinishLaunchingTimestamp) > backgroundLaunchThreshold {
                    // A delayed foreground boundary without trusted background
                    // provenance is intentionally suppressed; it must not become
                    // an artificially long cold start or an inferred warm start.
                    return nil
                }
            }

            return (.cold, startTime)
        }

        return nil
    }

    /// Determines an initial AppStart from explicit hybrid lifecycle evidence.
    func determinedSnapshotAppStartType(launchOrigin: AppStartLaunchOrigin) -> (AppStartType, Date)? {
        guard let didBecomeActiveTimestamp else {
            return nil
        }

        switch launchOrigin {
        case .foreground:
            guard let processStartTimestamp,
                processStartTimestamp <= didBecomeActiveTimestamp,
                validSnapshotEventTimes(end: didBecomeActiveTimestamp)
            else {
                return nil
            }

            return (.cold, processStartTimestamp)

        case .background:
            guard let willEnterForegroundTimestamp,
                capturedLaunchOriginConfidence == .observed,
                willEnterForegroundTimestamp <= didBecomeActiveTimestamp,
                validSnapshotEventTimes(end: didBecomeActiveTimestamp)
            else {
                return nil
            }

            return (.warm, willEnterForegroundTimestamp)

        case .unknown:
            // An unknown origin is not evidence for either cold or warm start. In
            // particular, do not use a duration threshold to turn untrusted
            // provenance into a customer-visible measurement.
            return nil
        }
    }
}
