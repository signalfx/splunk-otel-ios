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

typealias MRUMSessionReplayPreferences = CiscoSessionReplay.Preferences

// Internal extensions to convert `SessionReplayModulePreferences` proxy model to
// the underlying SessionReplay's `Preferences` model and vice versa.
extension MRUMSessionReplayPreferences {

    // MARK: - Initialization conversion

    convenience init(preferences: SessionReplayModulePreferences) {
        guard let srRenderingMode = preferences.renderingMode?.srRenderingMode else {
            self.init(renderingMode: .default)
            return
        }

        self.init(renderingMode: srRenderingMode)
    }
}

extension SessionReplayModulePreferences {

    // MARK: - Initialization conversion

    init(srPreferences: MRUMSessionReplayPreferences) {
        let renderingMode = RenderingMode(with: srPreferences.renderingMode)

        self.init(renderingMode: renderingMode)
    }
}
