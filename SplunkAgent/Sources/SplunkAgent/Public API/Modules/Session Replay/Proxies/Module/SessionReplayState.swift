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
internal import CiscoSessionReplay

/// The state object implements public API for the current state of the Session Replay module.
final class SessionReplayState: SessionReplayModuleState {

    // MARK: - Internal

    private(set) unowned var module: CiscoSessionReplay.SessionReplay


    // MARK: - Initialization

    init(for module: CiscoSessionReplay.SessionReplay) {
        self.module = module
    }


    // MARK: - Recording

    /// The current operational status of the Session Replay module.
    ///
    /// See ``SessionReplayStatus`` for possible values.
    public var status: SessionReplayStatus {
        SessionReplayStatus(srStatus: module.state.status)
    }

    /// A boolean value indicating whether the session is currently being recorded.
    ///
    /// This is a convenience property that returns `true` if the ``status`` is `.recording`,
    /// and `false` otherwise.
    public var isRecording: Bool {
        module.state.isRecording
    }


    // MARK: - Rendering

    // Temporarily removed with Rendering Modes.

    //    public var renderingMode: RenderingMode {
    //      RenderingMode(with: module.state.renderingMode)
    //  }
}
