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

/// An enumeration that defines the visual style of Session Replay recordings.
///
/// You can set this mode in the ``SessionReplayModulePreferences`` to balance between
/// visual fidelity and privacy.
///
/// ### Example ###
/// ```
/// var srPrefs = ConcreteSessionReplayPreferences()
/// srPrefs.renderingMode = .wireframeOnly
/// ```
public enum RenderingMode: Equatable, Codable {

    /// Records the session using a combination of screen captures and a wireframe overlay.
    ///
    /// This mode provides the highest visual fidelity by showing the actual screen content.
    case native

    /// Records the session using only a wireframe representation of the UI.
    ///
    /// This mode enhances privacy by not capturing actual screen images. Instead, it shows
    /// a structural layout of UI elements, which can also result in smaller recording sizes.
    case wireframeOnly
}


public extension RenderingMode {

    /// The default rendering mode, which is ``native``.
    static let `default` = RenderingMode.native
}