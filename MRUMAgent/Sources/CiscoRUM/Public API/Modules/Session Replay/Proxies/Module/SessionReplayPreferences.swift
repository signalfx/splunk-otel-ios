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

/// The preferences object is a representation of the user's preferred settings.
///
/// These are the settings that the user would like the Session Replay module to use.
/// The entered values always represent only the preferred settings, and the resulting state
/// in which the module works may be different for each property.
///
/// To find out the current state, use the information from the ``SessionReplayModuleState``.
///
/// - Note: If you want to set up a parameter, you can change the appropriate property
///         or use the proper method. Both approaches are comparable and give the same result.
public final class SessionReplayPreferences: SessionReplayModulePreferences, Codable {

    // MARK: - Internal

    unowned var module: CiscoSessionReplay.SessionReplay?


    // MARK: - Initialization

    required init() {
        module = nil
    }

    init(for module: CiscoSessionReplay.SessionReplay?) {
        self.module = module
        renderingMode = RenderingMode(with: module?.preferences.renderingMode)
    }


    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case renderingMode
    }


    // MARK: - Rendering

    public var renderingMode: RenderingMode? {
        didSet {
            module?.preferences.renderingMode = renderingMode?.srRenderingMode
        }
    }

    @discardableResult public func renderingMode(_ renderingMode: RenderingMode?) -> SessionReplayModulePreferences {
        self.renderingMode = renderingMode

        return self
    }
}


public extension SessionReplayPreferences {

    // MARK: - Convenience init

    convenience init(renderingMode: RenderingMode) {
        self.init(for: nil)

        self.renderingMode = renderingMode
    }
}
