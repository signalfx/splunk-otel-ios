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
        awaitingObservedBackgroundHandoff = false
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
        let lifecycleSegments = initialLifecycleSegments(from: snapshot)
        let initialSnapshot = lifecycleSegments.initial

        merge(initialLifecycle: initialSnapshot, acceptUnknownOrigin: false)

        if capturedLaunchOrigin == .background,
            capturedLaunchOriginConfidence == .inferred
        {
            awaitingObservedBackgroundHandoff = true
        }
        else if capturedLaunchOriginConfidence == .observed {
            awaitingObservedBackgroundHandoff = false
        }

        // A recorder update already contains the event in its snapshot history.
        // The event parameter is retained for callers that provide only a scalar update.
        if snapshot.events.isEmpty, let event {
            processCoreLifecycleEvent(event, resolve: false)
        }

        if awaitingObservedBackgroundHandoff {
            // A timing-only background inference can also describe a slow foreground
            // launch. Give a hybrid adapter a bounded window to replace it with its
            // observed origin before making the conservative suppression decision.
            scheduleInitialHandoffTimeout()
        }
        else if didBecomeActiveTimestamp != nil, hasRequiredBoundary(for: initialSnapshot.launchOrigin) {
            determineAndSend()
            if initialAppStartState.isTerminal {
                replaySubsequentLifecycleEvents(lifecycleSegments.subsequent)
                return
            }
        }

        if let terminationEvent = terminationEvent(in: initialSnapshot, fallback: event) {
            processCoreLifecycleEvent(terminationEvent)
            return
        }

        if isWaitingForBackgroundForegroundBoundary {
            cancelInitialHandoffTimeout()
        }
    }

    func initialLifecycleSegments(
        from snapshot: AppStartLifecycleSnapshot
    ) -> (initial: AppStartLifecycleSnapshot, subsequent: [AppLifecycleRecorder.EventRecord]) {
        guard hasCompleteLifecycleHistory(snapshot.events) else {
            // The recorder keeps the scalar first-event-wins fields after its
            // bounded history evicts old records. A truncated history cannot
            // identify the process' first activation, so never use its retained
            // records to replace those scalar fields or to replay later cycles.
            return (snapshotWithoutTruncatedHistory(snapshot), [])
        }

        guard let firstActivationIndex = snapshot.events.firstIndex(where: { $0.kind == .didBecomeActive }),
            firstActivationIndex < snapshot.events.index(before: snapshot.events.endIndex)
        else {
            return (snapshot, [])
        }

        let initialEvents = Array(snapshot.events[...firstActivationIndex])
        let subsequentEvents = Array(snapshot.events.dropFirst(firstActivationIndex + 1))
        let initialSnapshot = AppStartLifecycleSnapshot(
            launchOrigin: snapshot.launchOrigin,
            launchOriginConfidence: snapshot.launchOriginConfidence,
            didFinishLaunching: initialTimestamp(
                for: .didFinishLaunching,
                initialEvents: initialEvents,
                allEvents: snapshot.events,
                fallback: snapshot.didFinishLaunching
            ),
            willEnterForeground: initialTimestamp(
                for: .willEnterForeground,
                initialEvents: initialEvents,
                allEvents: snapshot.events,
                fallback: snapshot.willEnterForeground
            ),
            didBecomeActive: initialTimestamp(
                for: .didBecomeActive,
                initialEvents: initialEvents,
                allEvents: snapshot.events,
                fallback: snapshot.didBecomeActive
            ),
            recorderStartedAt: snapshot.recorderStartedAt,
            prewarmDetected: snapshot.prewarmDetected,
            events: initialEvents
        )

        return (initialSnapshot, subsequentEvents)
    }

    private func hasCompleteLifecycleHistory(_ events: [AppLifecycleRecorder.EventRecord]) -> Bool {
        guard let firstEvent = events.first else {
            return true
        }

        return firstEvent.sequence == 1
    }

    private func snapshotWithoutTruncatedHistory(
        _ snapshot: AppStartLifecycleSnapshot
    ) -> AppStartLifecycleSnapshot {
        let willEnterForeground = snapshot.willEnterForeground.flatMap { timestamp in
            guard let didBecomeActive = snapshot.didBecomeActive,
                timestamp > didBecomeActive
            else {
                return timestamp
            }

            // A foreground boundary after the preserved first activation belongs
            // to a later cycle and must not complete the initial snapshot.
            return nil
        }

        return AppStartLifecycleSnapshot(
            launchOrigin: snapshot.launchOrigin,
            launchOriginConfidence: snapshot.launchOriginConfidence,
            didFinishLaunching: snapshot.didFinishLaunching,
            willEnterForeground: willEnterForeground,
            didBecomeActive: snapshot.didBecomeActive,
            recorderStartedAt: snapshot.recorderStartedAt,
            prewarmDetected: snapshot.prewarmDetected
        )
    }

    private func initialTimestamp(
        for kind: AppLifecycleRecorder.EventKind,
        initialEvents: [AppLifecycleRecorder.EventRecord],
        allEvents: [AppLifecycleRecorder.EventRecord],
        fallback: Date?
    ) -> Date? {
        if let timestamp = initialEvents.first(where: { $0.kind == kind })?.timestamp {
            return timestamp
        }

        return allEvents.contains(where: { $0.kind == kind }) ? nil : fallback
    }

    func replaySubsequentLifecycleEvents(_ events: [AppLifecycleRecorder.EventRecord]) {
        for record in events {
            processCoreLifecycleEvent(record.event)
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
