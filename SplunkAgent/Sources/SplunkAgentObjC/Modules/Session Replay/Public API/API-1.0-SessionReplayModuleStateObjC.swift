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
import SplunkAgent

/// A Session Replay state class reflects the current state of the module.
///
/// The individual properties are a combination of:
/// - Default settings.
/// - Initial default configuration.
/// - Preferred behavior.
///
/// - Note: The states of individual properties in this class can
///         and usually also change during the application's runtime.
@objc(SPLKSessionReplayModuleState)
public final class SessionReplayModuleStateObjC: NSObject {

    // MARK: - Internal

    private unowned let owner: SplunkRumObjC


    // MARK: - Recording

    /// A status of module recording.
    ///
    /// A `NSNumber` which value can be mapped to the `SPLKSessionReplayStatus` constants.
    @objc
    public var status: NSNumber {
        let status = owner.agent.sessionReplay.state.status

        return SessionReplayStatusObjC.value(for: status)
    }

    /// Indicates whether module is recording.
    ///
    /// For detailed info about status, see `status`.
    @objc
    public var isRecording: Bool {
        owner.agent.sessionReplay.state.isRecording
    }


    // MARK: - Rendering

    /// Indicates the rendering mode for capturing video.
    ///
    /// A `NSNumber` which value can be mapped to the `SPLKRenderingMode` constants.
    @objc
    public var renderingMode: NSNumber {
        let mode = owner.agent.sessionReplay.state.renderingMode

        return RenderingModeObjC.value(for: mode)
    }


    // MARK: - Initialization

    init(for owner: SplunkRumObjC) {
        self.owner = owner
    }
}
