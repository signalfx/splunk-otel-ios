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

    /// Supplies legacy lifecycle timestamps captured before installation.
    ///
    /// This overload cannot establish launch provenance by itself. New hybrid
    /// integrations should use ``track(initialLifecycle:)``; ambiguous legacy
    /// handoffs are suppressed.
    ///
    /// - Parameters:
    ///   - didBecomeActive: The activation timestamp and exact measurement end.
    ///   - didFinishLaunching: The optional launch timestamp.
    ///   - willEnterForeground: The optional warm-start boundary.
    ///
    /// - Returns: The actual ``AppStartModule`` instance.
    ///
    /// - Warning: For internal compatibility only.
    @_spi(SplunkInternal)
    @available(*, deprecated, message: "Use track(initialLifecycle:) to supply explicit launch provenance.")
    func track(didBecomeActive: Date, didFinishLaunching: Date?, willEnterForeground: Date?) -> any AppStartModule

    /// Supplies lifecycle evidence captured before agent installation.
    ///
    /// Call this exactly once immediately after `install()`, including when the
    /// snapshot is partial. The native observer completes a pending activation;
    /// the native reducer owns classification, validation, and suppression.
    /// Calls before installation are discarded, and repeated handoffs are suppressed.
    /// Snapshots supplied after initial resolution are ignored.
    /// Measurements longer than ten seconds are suppressed.
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
