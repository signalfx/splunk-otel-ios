//
/*
Copyright 2024 Splunk Inc.

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
@_implementationOnly import CiscoSessionReplay

/// The state object implements public API for the current state of the Session Replay module.
final class SessionReplayState: SessionReplayModuleState {

    // MARK: - Internal

    private(set) unowned var module: CiscoSessionReplay.SessionReplay


    // MARK: - Initialization

    init(for module: CiscoSessionReplay.SessionReplay) {
        self.module = module
    }


    // MARK: - Recording

    public var status: SessionReplayStatus {
        SessionReplayStatus(srStatus: module.state.status)
    }

    public var isRecording: Bool {
        module.state.isRecording
    }


    // MARK: - Rendering

    // Temporarily removed with Rendering Modes.

    //    public var renderingMode: RenderingMode {
    //      RenderingMode(with: module.state.renderingMode)
    //  }
}
