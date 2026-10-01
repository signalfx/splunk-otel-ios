//
/*
Copyright 2025 Splunk Inc.

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
@_spi(SplunkInternal) internal import SplunkAppStart

extension AppStart {

    // MARK: - Manual detection

    @discardableResult
    @available(*, deprecated, message: "Use track(initialLifecycle:) to supply explicit launch provenance.")
    func track(didBecomeActive: Date, didFinishLaunching: Date?, willEnterForeground: Date?) -> any AppStartModule {
        module.track(
            didBecomeActive: didBecomeActive,
            didFinishLaunching: didFinishLaunching,
            willEnterForeground: willEnterForeground
        )

        return self
    }

    @discardableResult
    func track(initialLifecycle snapshot: AppStartLifecycleSnapshot) -> any AppStartModule {
        module.track(
            initialLifecycle: SplunkAppStart.AppStartLifecycleSnapshot(
                launchOrigin: snapshot.launchOrigin.moduleValue,
                didFinishLaunching: snapshot.didFinishLaunching,
                willEnterForeground: snapshot.willEnterForeground,
                didBecomeActive: snapshot.didBecomeActive
            )
        )

        return self
    }
}

extension AppStartLifecycleSnapshot.LaunchOrigin {

    // MARK: - Module conversion

    var moduleValue: SplunkAppStart.AppStartLifecycleSnapshot.LaunchOrigin {
        // Keep this exhaustive conversion synchronized with the peer SPI enum in
        // SplunkAppStart/Model/AppStartLifecycleSnapshot.swift.
        switch self {
        case .foreground:
            return .foreground

        case .background:
            return .background

        case .foregroundResumed:
            return .foregroundResumed

        case .unknown:
            return .unknown
        }
    }
}
