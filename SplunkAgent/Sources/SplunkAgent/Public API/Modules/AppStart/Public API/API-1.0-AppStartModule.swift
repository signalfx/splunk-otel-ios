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
@_spi(SplunkInternal) public import SplunkAppStart

/// The canonical initial lifecycle snapshot consumed by the native AppStart module.
@_spi(SplunkInternal)
public typealias AppStartLifecycleSnapshot = SplunkAppStart.AppStartLifecycleSnapshot

/// Compatibility name for the canonical AppStart launch-origin type.
@_spi(SplunkInternal)
public typealias AppStartLaunchOrigin = SplunkAppStart.AppStartLaunchOrigin

/// Defines a public API for the AppStart module.
///
/// Currently all APIs are for internal use only.
public protocol AppStartModule {

    // MARK: - Manual app start detection

    /// This method is for internal use only.
    ///
    /// App start event and it's type are determined and sent based on `UIApplication`'s lifecycle notifications. If agent's `install()` is called after
    /// receiving the `UIApplication.didBecomeActive`, app start event is not determined and is not sent.
    ///
    /// This method allows bridges (React, Flutter etc.) to track app lifecycle notifications timestamps to determine and send the app start event manually.
    ///
    /// This method should be called as soon as possible, but not sooner that the agent's `install()` method.
    /// Method call is ignored if an initial app start event has has already been sent, either automatically or by using this method.
    ///
    /// - Parameters:
    ///   - didBecomeActive: A timestamp of the `UIApplication.didBecomeActive` notification. Needed for type determination and sending.
    ///   - didFinishLaunching: An optional timestamp of the `UIApplication.didFinishLaunching` notification.
    ///   Does not determine AppStart type, but is sent as a metadata.
    ///   - willEnterForeground: An optional timestamp of the `UIApplication.willEnterForeground` notification.
    ///   Does not determine AppStart type, but is sent as a metadata.
    ///
    /// - Returns: The actual ``AppStartModule`` instance.
    ///
    /// - Warning: Internal use only.
    @_spi(SplunkInternal)
    func track(didBecomeActive: Date, didFinishLaunching: Date?, willEnterForeground: Date?) -> any AppStartModule

    /// Adopts initial lifecycle evidence captured before a hybrid agent installed the native SDK.
    ///
    /// - Parameter snapshot: Immutable initial lifecycle evidence captured by a hybrid agent. A partial
    ///   snapshot is retained until the native observer receives `didBecomeActive`.
    /// - Returns: The actual ``AppStartModule`` instance.
    ///
    /// - Warning: Internal use only.
    @_spi(SplunkInternal)
    func track(initialLifecycle snapshot: AppStartLifecycleSnapshot) -> any AppStartModule
}

/// Default implementation required for BUILD_LIBRARY_FOR_DISTRIBUTION
/// compatibility. @_spi protocol requirements must have a default
/// implementation in library evolution mode.
extension AppStartModule {

    @_spi(SplunkInternal)
    public func track(didBecomeActive: Date, didFinishLaunching: Date?, willEnterForeground: Date?) -> any AppStartModule {
        track(initialLifecycle: AppStartLifecycleSnapshot(
            launchOrigin: .unknown,
            didFinishLaunching: didFinishLaunching,
            willEnterForeground: willEnterForeground,
            didBecomeActive: didBecomeActive
        ))
    }

    @_spi(SplunkInternal)
    public func track(
        didBecomeActive: Date,
        didFinishLaunching: Date?,
        willEnterForeground: Date?,
        launchOrigin: AppStartLaunchOrigin
    ) -> any AppStartModule {
        track(initialLifecycle: AppStartLifecycleSnapshot(
            launchOrigin: launchOrigin,
            didFinishLaunching: didFinishLaunching,
            willEnterForeground: willEnterForeground,
            didBecomeActive: didBecomeActive
        ))
    }

    @_spi(SplunkInternal)
    public func track(initialLifecycle snapshot: AppStartLifecycleSnapshot) -> any AppStartModule {
        // Intentionally unused
        _ = snapshot

        return self
    }
}
