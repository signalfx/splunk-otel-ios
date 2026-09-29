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

extension AppLifecycleRecorder {
    func updateLaunchOriginAtProcessStart() {
        #if canImport(UIKit)
            // During the initial UIKit transition, `didFinishLaunching` may
            // report `.background` even for a user-visible cold launch. Only
            // `.active` is sufficient evidence at this point; a background
            // origin must be confirmed by later lifecycle history.
            if UIApplication.shared.applicationState == .active {
                launchOrigin = .foreground
                launchOriginConfidence = .observed
            }
        #endif
    }

    func isBackgroundLaunch(timestamp: Date) -> Bool {
        // UIApplication can still report `.background` while delivering
        // `willEnterForeground` for a normal cold launch. Require lifecycle
        // evidence from before that boundary instead of treating the current
        // transitional state as proof of a background launch.
        if eventHistory.contains(where: { $0.kind == .didEnterBackground }) {
            return true
        }

        guard let didFinishLaunchingTimestamp else {
            return false
        }

        return timestamp.timeIntervalSince(didFinishLaunchingTimestamp) > backgroundLaunchThreshold
    }

    func makeSnapshot() -> Snapshot {
        Snapshot(
            recorderStartedAt: recorderStartedAt,
            prewarmDetected: prewarmDetected,
            launchOrigin: launchOrigin,
            launchOriginConfidence: launchOriginConfidence,
            didFinishLaunching: didFinishLaunchingTimestamp,
            willEnterForeground: willEnterForegroundTimestamp,
            didBecomeActive: didBecomeActiveTimestamp,
            events: eventHistory
        )
    }

    func captureInitialApplicationStateIfAvailable() {
        #if canImport(UIKit)
            guard Thread.isMainThread else {
                return
            }

            switch UIApplication.shared.applicationState {
            case .active:
                launchOrigin = .foreground
                launchOriginConfidence = .observed

            case .background:
                launchOrigin = .background
                launchOriginConfidence = .observed

            case .inactive:
                launchOrigin = .unknown

            @unknown default:
                launchOrigin = .unknown
            }
        #endif
    }

    func currentApplicationState() -> ApplicationState {
        #if canImport(UIKit)
            switch UIApplication.shared.applicationState {
            case .active:
                return .active

            case .inactive:
                return .inactive

            case .background:
                return .background

            @unknown default:
                return .unknown
            }
        #else
            return .unknown
        #endif
    }

    func launchOptionKeys(from notification: Notification) -> [String] {
        guard notification.name == UIApplication.didFinishLaunchingNotification else {
            return []
        }

        guard let userInfo = notification.userInfo else {
            return []
        }

        return userInfo.keys
            .compactMap { key in
                if let key = key as? String {
                    return key
                }

                if let key = key as? UIApplication.LaunchOptionsKey {
                    return key.rawValue
                }

                return String(describing: key)
            }
            .sorted()
    }

    var isApplicationInBackground: Bool {
        #if canImport(UIKit)
            return UIApplication.shared.applicationState == .background
        #else
            return false
        #endif
    }

    func withLock<Result>(_ work: () -> Result) -> Result {
        lock.lock()
        defer { lock.unlock() }
        return work()
    }
}
