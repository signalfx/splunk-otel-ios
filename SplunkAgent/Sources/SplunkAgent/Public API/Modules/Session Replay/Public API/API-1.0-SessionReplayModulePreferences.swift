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

/// An interface for configuring Session Replay settings, such as the video rendering mode.
public protocol SessionReplayModulePreferences {

    // MARK: - Rendering

    /// The rendering mode used for Session Replay videos.
    ///
    /// See ``RenderingMode`` for available options. Setting this property to `nil`
    /// restores the default rendering mode.
    var renderingMode: RenderingMode? { get set }

    /// Sets the rendering mode for Session Replay videos.
    ///
    /// - Parameter renderingMode: The ``RenderingMode`` to apply. Pass `nil` to restore the default behavior.
    /// - Returns: The updated preferences object to allow for chaining.
    @discardableResult func renderingMode(_ renderingMode: RenderingMode?) -> any SessionReplayModulePreferences


    // MARK: - Convenience init

    /// Initializes a new preferences object with a specific rendering mode.
    ///
    /// - Parameter renderingMode: The ``RenderingMode`` to use for recordings.
    ///
    /// ### Example ###
    /// ```
    /// // Create preferences to use the screen-based rendering mode
    /// let srPrefs = ConcreteSessionReplayPreferences(renderingMode: .screen)
    /// SplunkRum.shared.sessionReplay.preferences(srPrefs)
    /// ```
    init(renderingMode: RenderingMode)
}