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
@_spi(SplunkInternal) import SplunkCommon

extension AppStart {

    /// Replaces the module's temporary notification listeners with the agent-core recorder.
    @_spi(SplunkInternal)
    public func resetLifecycleObservationState() {
        stopDetection()
        didFinishLaunchingTimestamp = nil
        willEnterForegroundTimestamp = nil
        willResignActiveTimestamp = nil
        didBecomeActiveTimestamp = nil
        backgroundLaunchDetected = nil
        backgroundLaunchConfidence = .unknown
        capturedLaunchOrigin = nil
        capturedLaunchOriginConfidence = .unknown
        suppressionCounts.removeAll()
        deferredLifecycleSnapshot = nil
        shouldDeferInitialLifecycleResolution = false
    }

    /// Consumes the snapshot recorded by the agent core.
    ///
    /// A complete, trusted snapshot can resolve immediately. Unknown or partial
    /// foreground provenance remains pending for the bounded hybrid handoff timeout.
    /// An observed background launch without a foreground boundary remains pending until
    /// the boundary arrives or process termination provides a terminal outcome.
    @_spi(SplunkInternal)
    public func consume(coreLifecycle snapshot: AppStartLifecycleSnapshot) {
        consume(coreLifecycle: nil, snapshot: snapshot)
    }

    /// Consumes a core lifecycle event and its current initial snapshot.
    @_spi(SplunkInternal)
    public func consume(
        coreLifecycle event: AppLifecycleRecorder.Event?,
        snapshot: AppStartLifecycleSnapshot
    ) {
        executeOnMain { [self] in
            consumeOnMain(coreLifecycle: event, snapshot: snapshot)
        }
    }

    private func consumeOnMain(
        coreLifecycle event: AppLifecycleRecorder.Event?,
        snapshot: AppStartLifecycleSnapshot
    ) {
        if shouldDeferInitialLifecycleResolution,
            initialAppStartState == .pending
        {
            deferredLifecycleSnapshot = snapshot
            return
        }

        switch initialAppStartState {
        case .suppressed:
            if let event {
                processCoreLifecycleEvent(event)
            }

        case .emitted:
            if let event {
                processCoreLifecycleEvent(event)
            }

        case .pending:
            consumePending(coreLifecycle: event, snapshot: snapshot)
        }
    }

    private func consumePending(
        coreLifecycle event: AppLifecycleRecorder.Event?,
        snapshot: AppStartLifecycleSnapshot
    ) {
        merge(initialLifecycle: snapshot, acceptUnknownOrigin: false)

        // A recorder update already contains the event in its snapshot history.
        // The event parameter is retained for callers that provide only a scalar update.
        if snapshot.events.isEmpty, let event {
            processCoreLifecycleEvent(event, resolve: false)
        }

        if didBecomeActiveTimestamp != nil, hasRequiredBoundary(for: snapshot.launchOrigin) {
            determineAndSend()
            if initialAppStartState.isTerminal {
                return
            }
        }

        if let terminationEvent = terminationEvent(in: snapshot, fallback: event) {
            processCoreLifecycleEvent(terminationEvent)
            return
        }

        if isWaitingForBackgroundForegroundBoundary {
            cancelInitialHandoffTimeout()
        }
    }

    private func hasRequiredBoundary(for launchOrigin: AppStartLifecycleSnapshot.LaunchOrigin) -> Bool {
        switch launchOrigin {
        case .foreground:
            return processStartTimestamp != nil

        case .background:
            return willEnterForegroundTimestamp != nil

        case .unknown:
            return false
        }
    }

    private func terminationEvent(
        in snapshot: AppStartLifecycleSnapshot,
        fallback event: AppLifecycleRecorder.Event?
    ) -> AppLifecycleRecorder.Event? {
        if let termination = snapshot.events.last(where: { $0.kind == .willTerminate }) {
            return termination.event
        }

        if let event, case .willTerminate = event {
            return event
        }

        return nil
    }

    /// Validates optional lifecycle events supplied by a hybrid integration.
    func validSnapshotEventTimes(end: Date) -> Bool {
        let timestamps = [
            processStartTimestamp,
            didFinishLaunchingTimestamp,
            willEnterForegroundTimestamp,
            didBecomeActiveTimestamp,
            end
        ]
        .reduce(into: [Date]()) { timestamps, timestamp in
            if let timestamp {
                timestamps.append(timestamp)
            }
        }

        guard timestamps.allSatisfy(\.timeIntervalSinceReferenceDate.isFinite) else {
            return false
        }

        if let processStartTimestamp,
            let didFinishLaunchingTimestamp,
            processStartTimestamp > didFinishLaunchingTimestamp
        {
            return false
        }

        if let processStartTimestamp,
            let willEnterForegroundTimestamp,
            processStartTimestamp > willEnterForegroundTimestamp
        {
            return false
        }

        if let didFinishLaunchingTimestamp,
            didFinishLaunchingTimestamp > end
        {
            return false
        }

        if let willEnterForegroundTimestamp,
            willEnterForegroundTimestamp > end
        {
            return false
        }

        if let processStartTimestamp,
            processStartTimestamp > end
        {
            return false
        }

        if let didFinishLaunchingTimestamp,
            let willEnterForegroundTimestamp,
            didFinishLaunchingTimestamp > willEnterForegroundTimestamp
        {
            return false
        }

        return true
    }
}
