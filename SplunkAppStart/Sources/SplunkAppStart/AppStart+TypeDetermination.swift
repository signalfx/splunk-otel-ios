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

        if case .suppressed = initialAppStartState {
            logger.log(level: .debug) {
                "App start resolution has already reached a terminal state. Ignoring lifecycle event."
            }
            return
        }

        guard !isWaitingForBackgroundForegroundBoundary else {
            return
        }

        // Reset state for further app start detection
        defer {
            // Clear timestamps
            didFinishLaunchingTimestamp = nil
            willEnterForegroundTimestamp = nil
            willResignActiveTimestamp = nil
            didBecomeActiveTimestamp = nil
            capturedLaunchOrigin = nil
            capturedLaunchOriginConfidence = .unknown
            backgroundLaunchConfidence = .unknown

            // Clear initialization data as initialization span is sent only once with the cold start
            agentInitializeSpanData = nil
        }

        guard let endTime = didBecomeActiveTimestamp else {
            logger.log(level: .debug) {
                "Cannot determine app start without a didBecomeActive timestamp."
            }
            return
        }

        // Send app start if the type was determined
        if let (determinedType, startTime) = determinedAppStartType() {
            guard startTime.timeIntervalSinceReferenceDate.isFinite,
                endTime.timeIntervalSinceReferenceDate.isFinite,
                startTime <= endTime
            else {
                suppressInitialAppStart(reason: .invalidTimestampOrder)
                return
            }

            let duration = endTime.timeIntervalSince(startTime)
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
            send(start: startTime, end: endTime, type: determinedType)

            logger.log(level: .debug) {
                "App start log: determined app start type: \(determinedType.rawValue), start time: \(startTime), end time: \(endTime)."
            }
        }
        else {
            suppressInitialAppStart(reason: suppressionReason())
        }
    }

    /// Determines app start type from available notifications timestamps.
    func determinedAppStartType() -> (AppStartType, Date)? {
        guard let didBecomeActiveTimestamp else {
            return nil
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

        if willResignActiveTimestamp != nil, let startTime = willEnterForegroundTimestamp {
            return (.hot, startTime)
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
