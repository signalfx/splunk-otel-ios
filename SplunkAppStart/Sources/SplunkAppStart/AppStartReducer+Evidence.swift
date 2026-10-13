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
import UIKit

extension AppStartReducer.Evidence {

    // MARK: - Recording

    func recordingLaunch(
        _ timestamp: Date,
        launchOrigin observedOrigin: AppStartReducer.LaunchOrigin
    ) -> Self {
        var evidence = self
        evidence.didFinishLaunching = first(didFinishLaunching, timestamp)
        evidence.launchOrigin = combinedOrigin(with: observedOrigin)

        return evidence
    }

    func recordingForeground(_ timestamp: Date) -> Self {
        var evidence = self

        // Native evidence replaces a boundary imported before SDK installation.
        evidence.foregroundBoundary = .native(timestamp)
        return evidence
    }

    func recordingActivation(_ timestamp: Date) -> Self {
        var evidence = self
        evidence.didBecomeActive = first(didBecomeActive, timestamp)
        return evidence
    }

    func recordingBackground() -> Self {
        var evidence = self

        switch launchOrigin {
        case .foreground:
            evidence.launchOrigin = .foregroundResumed

        case .unknown:
            evidence.launchOrigin = .ambiguous

        case .ambiguous,
            .background,
            .conflicting,
            .foregroundResumed,
            .prewarmed:
            break
        }

        evidence.foregroundBoundary = nil
        return evidence
    }

    func merging(_ snapshot: AppStartLifecycleSnapshot) -> Self {
        var evidence = self
        evidence.hybridHandoff = .received
        evidence.launchOrigin = mergedOrigin(with: snapshot.launchOrigin)
        evidence.didFinishLaunching = first(
            didFinishLaunching,
            snapshot.didFinishLaunching
        )
        if evidence.foregroundBoundary == nil,
            let willEnterForeground = snapshot.willEnterForeground
        {
            // Installation can occur between willEnterForeground and
            // didBecomeActive. Keep that early boundary pending so the native
            // observer can complete the same activation.
            evidence.foregroundBoundary = .hybrid(willEnterForeground)
        }
        evidence.didBecomeActive = first(
            didBecomeActive,
            snapshot.didBecomeActive
        )

        return evidence
    }


    // MARK: - Validation and events

    var willEnterForeground: Date? {
        foregroundBoundary?.timestamp
    }

    var hasNativeForegroundBoundary: Bool {
        foregroundBoundary?.isNative == true
    }

    var hasValidTimestamps: Bool {
        let optionalDates = [
            processStart,
            didFinishLaunching,
            willEnterForeground,
            didBecomeActive
        ]
        let dates = optionalDates.compactMap(\.self)

        guard dates.allSatisfy(AppStartReducer.valid) else {
            return false
        }

        if let processStart {
            guard dates.allSatisfy({ processStart <= $0 }) else {
                return false
            }
        }

        guard let didBecomeActive else {
            if let didFinishLaunching, let willEnterForeground {
                return didFinishLaunching <= willEnterForeground
            }

            return true
        }

        return
            (didFinishLaunching.map { launch in
                (willEnterForeground.map { launch <= $0 } ?? true)
                    && launch <= didBecomeActive
            } ?? true)
            && (willEnterForeground.map { $0 <= didBecomeActive } ?? true)
    }

    var coldEvents: [AppStartEvent] {
        [
            processStart.map { AppStartEvent(name: "process.start", timestamp: $0) },
            didFinishLaunching.map {
                AppStartEvent(
                    name: UIApplication.didFinishLaunchingNotification.rawValue,
                    timestamp: $0
                )
            },
            didBecomeActive.map {
                AppStartEvent(
                    name: UIApplication.didBecomeActiveNotification.rawValue,
                    timestamp: $0
                )
            }
        ]
        .compactMap(\.self)
        .sorted { $0.timestamp < $1.timestamp }
    }


    // MARK: - Origin

    private func mergedOrigin(
        with snapshotOrigin: AppStartLifecycleSnapshot.LaunchOrigin
    ) -> AppStartReducer.LaunchOrigin {
        switch snapshotOrigin {
        case .background:
            return combinedOrigin(with: .background)

        case .foreground:
            return combinedOrigin(with: .foreground)

        case .foregroundResumed:
            return combinedOrigin(with: .foregroundResumed)

        case .unknown:
            return combinedOrigin(with: .ambiguous)
        }
    }

    private func combinedOrigin(
        with observedOrigin: AppStartReducer.LaunchOrigin
    ) -> AppStartReducer.LaunchOrigin {
        if observedOrigin == .unknown || observedOrigin == .ambiguous {
            return launchOrigin == .unknown ? .ambiguous : launchOrigin
        }

        if launchOrigin == .prewarmed || launchOrigin == .conflicting {
            return launchOrigin
        }

        if launchOrigin == .unknown || launchOrigin == .ambiguous {
            return observedOrigin
        }

        if launchOrigin == observedOrigin {
            return launchOrigin
        }

        if launchOrigin == .foreground,
            observedOrigin == .foregroundResumed
        {
            return .foregroundResumed
        }

        if launchOrigin == .foregroundResumed,
            observedOrigin == .foreground
        {
            return .foregroundResumed
        }

        return .conflicting
    }

    private func first(_ current: Date?, _ candidate: Date?) -> Date? {
        guard let candidate else {
            return current
        }

        guard let current else {
            return candidate
        }

        return min(current, candidate)
    }
}
