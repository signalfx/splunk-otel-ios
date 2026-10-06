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

/// Defines the AppStart API used by hybrid integrations.
public protocol AppStartModule {

    // MARK: - Manual app start detection

    /// This method is for internal use only.
    ///
    /// App start event and its type are determined and sent based on `UIApplication` lifecycle notifications. If agent `install()` is called after
    /// receiving `UIApplication.didBecomeActive`, the legacy timestamps cannot reliably establish launch provenance and the ambiguous event is suppressed.
    ///
    /// This method allows bridges (React, Flutter etc.) to track app lifecycle notifications timestamps to determine and send the app start event manually.
    ///
    /// This method should be called as soon as possible, but not sooner that the agent's `install()` method.
    /// Method call is ignored if the initial app start attempt has already resolved, either automatically or by using this method.
    /// Hybrid integrations that install after the initial lifecycle must use
    /// ``track(initialLifecycle:)``; this legacy overload intentionally suppresses
    /// a completed handoff when native evidence did not establish launch provenance.
    ///
    /// - Parameters:
    ///   - didBecomeActive: A timestamp of the `UIApplication.didBecomeActive` notification. Used as the exact measurement end.
    ///   - didFinishLaunching: An optional timestamp of the `UIApplication.didFinishLaunching` notification.
    ///   Used as cold-start metadata when native evidence has established a foreground launch.
    ///   - willEnterForeground: An optional timestamp of the `UIApplication.willEnterForeground` notification.
    ///   Used as the warm-start boundary when launch provenance is available from native evidence.
    ///
    /// - Returns: The actual ``AppStartModule`` instance.
    ///
    /// - Warning: Internal use only.
    @_spi(SplunkInternal)
    @available(*, deprecated, message: "Use track(initialLifecycle:) to supply explicit launch provenance.")
    func track(didBecomeActive: Date, didFinishLaunching: Date?, willEnterForeground: Date?) -> any AppStartModule

    /// Supplies initial lifecycle evidence captured before agent installation.
    ///
    /// Hybrid integrations should capture the first lifecycle timestamps and launch
    /// provenance as early as their existing native bootstrap permits. Hybrid adapters
    /// own only this early capture; classification remains owned by the native AppStart
    /// state machine and does not require a new core load-time constructor.
    /// If an activation is interrupted by a background transition, the integration
    /// must use ``AppStartLifecycleSnapshot/LaunchOrigin/foregroundResumed`` and
    /// replace that foreground timestamp with the boundary paired with the supplied
    /// activation.
    /// Call this method exactly once, immediately after agent `install()` completes,
    /// even if `didBecomeActive` has not occurred yet. The installed native observer
    /// completes a partial foreground/active pair and clears it if the app backgrounds
    /// before activation.
    /// Every resolved cold, warm, or hot measurement is subject to AppStart's
    /// five-second maximum duration guard. Longer measurements are suppressed.
    /// Calls made before installation reach the non-operational proxy and are discarded.
    /// Repeated handoffs are treated as conflicting evidence and suppressed.
    ///
    /// - Parameter snapshot: Initial lifecycle evidence captured by the integration.
    ///
    /// - Returns: The actual ``AppStartModule`` instance.
    ///
    func track(initialLifecycle snapshot: AppStartLifecycleSnapshot) -> any AppStartModule
}

/// Default implementation required for BUILD_LIBRARY_FOR_DISTRIBUTION
/// compatibility. Protocol requirements must have a default implementation
/// in library evolution mode.
extension AppStartModule {

    @_spi(SplunkInternal)
    @available(*, deprecated, message: "Use track(initialLifecycle:) to supply explicit launch provenance.")
    public func track(didBecomeActive: Date, didFinishLaunching: Date?, willEnterForeground: Date?) -> any AppStartModule {
        // Intentionally unused
        _ = didBecomeActive
        _ = didFinishLaunching
        _ = willEnterForeground

        return self
    }

    public func track(initialLifecycle snapshot: AppStartLifecycleSnapshot) -> any AppStartModule {
        // Intentionally unused
        _ = snapshot

        return self
    }
}
