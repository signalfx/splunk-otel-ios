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

/// The class implements the Session Replay module configuration.
@objc(SPLKSessionReplayConfiguration)
@objcMembers
public final class SessionReplayConfigurationObjC: ModuleConfigurationObjC {

    // MARK: - Module management

    /// Optional local sampling of session replay recording.
    ///
    /// The value sets the probability with which session replay recording
    /// is enabled for the current app launch. The sampling decision is made
    /// once per Agent lifecycle and is not re-evaluated on session rotation.
    ///
    /// - `nil` means the sampling rate is ignored (equivalent to `1`).
    /// - Values outside the `<0, 1>` range are clamped.
    /// - If `isEnabled` is set to `NO`, the sampling rate is ignored.
    ///
    /// Default value is `nil`.
    public var samplingRate: NSNumber?


    // MARK: - Initialization

    /// Initializes new module configuration.
    override public init() {
        super.init()
    }

    /// Initializes new module configuration with preconfigured values.
    ///
    /// - Parameter isEnabled: A `BOOL` value sets whether the module is enabled.
    @objc(initWithEnabled:)
    public init(isEnabled: Bool) {
        super.init()

        self.isEnabled = isEnabled
    }

    /// Initializes new module configuration with preconfigured values.
    ///
    /// - Parameters:
    ///   - isEnabled: A `BOOL` value sets whether the module is enabled.
    ///   - samplingRate: An optional probability value in the `<0, 1>` range
    ///     that controls whether session replay recording is enabled for the
    ///     current app launch. Pass `nil` to ignore sampling (equivalent to `1`).
    @objc(initWithEnabled:samplingRate:)
    public init(isEnabled: Bool, samplingRate: NSNumber?) {
        super.init()

        self.isEnabled = isEnabled
        self.samplingRate = samplingRate
    }
}
