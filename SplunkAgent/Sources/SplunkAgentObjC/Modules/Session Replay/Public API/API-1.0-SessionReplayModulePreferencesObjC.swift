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

/// The Session Replay preferences object represents the preferred settings related to the module.
@objc(SPLKSessionReplayModulePreferences)
public final class SessionReplayModulePreferencesObjC: NSObject {

    // MARK: - Internal

    private unowned let owner: SplunkRumObjC


    // MARK: - Rendering

    /// The video rendering mode for captured data.
    ///
    /// A `NSNumber` which value can be mapped to the `SPLKRenderingMode` constants.
    @objc
    public var renderingMode: NSNumber? {
        get {
            guard let mode = owner.agent.sessionReplay.preferences.renderingMode else {
                return nil
            }

            return RenderingModeObjC.value(for: mode)
        }
        set {
            guard let newValue else {
                owner.agent.sessionReplay.preferences.renderingMode = nil

                return
            }

            let mode = RenderingModeObjC.renderingMode(for: newValue)
            owner.agent.sessionReplay.preferences.renderingMode = mode
        }
    }


    // MARK: - Initialization

    init(for owner: SplunkRumObjC) {
        self.owner = owner
    }
}
