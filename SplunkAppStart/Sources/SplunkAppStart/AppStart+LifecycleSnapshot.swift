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
@_spi(SplunkInternal) internal import SplunkCommon

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
        capturedLaunchOrigin = nil
    }

    /// Consumes the snapshot recorded by the agent core.
    ///
    /// A complete, trusted snapshot can resolve immediately. Unknown or partial
    /// provenance remains pending for the bounded hybrid handoff timeout so a
    /// maintained integration can provide more precise evidence asynchronously.
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
            switch initialAppStartState {
            case .suppressed:
                return

            case .emitted:
                if let event {
                    processCoreLifecycleEvent(event)
                }

            case .pending:
                merge(initialLifecycle: snapshot, acceptUnknownOrigin: false)

                let hasActivation = didBecomeActiveTimestamp != nil
                let hasRequiredBoundary: Bool

                switch snapshot.launchOrigin {
                case .foreground:
                    hasRequiredBoundary = processStartTimestamp != nil

                case .background:
                    hasRequiredBoundary = willEnterForegroundTimestamp != nil

                case .unknown:
                    hasRequiredBoundary = false
                }

                if hasActivation, hasRequiredBoundary {
                    determineAndSend()
                }
                else {
                    scheduleInitialHandoffTimeout()
                }
            }
        }
    }

    /// Validates optional lifecycle events supplied by a hybrid integration.
    func validSnapshotEventTimes(end: Date) -> Bool {
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

        if let didFinishLaunchingTimestamp,
            let willEnterForegroundTimestamp,
            didFinishLaunchingTimestamp > willEnterForegroundTimestamp
        {
            return false
        }

        return true
    }
}
