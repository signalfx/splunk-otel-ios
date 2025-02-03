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

/// Defines a public API for the user's preferred settings.
public protocol SessionReplayModulePreferences {

    // MARK: - Rendering

    /// The video rendering mode for captured data.
    var renderingMode: RenderingMode? { get set }

    /// Sets video rendering mode for captured data.
    ///
    /// - Parameter renderingMode: The required rendering mode.
    ///
    /// - Returns: The updated preferences object.
    @discardableResult func renderingMode(_ renderingMode: RenderingMode?) -> any SessionReplayModulePreferences


    // MARK: - Convenience init

    /// Initializes new preferences object with preconfigured values.
    ///
    /// - Parameters:
    ///   - renderingMode: The required rendering mode.
    ///
    /// - Returns: A newly initialized `Preferences` object.
    init(renderingMode: RenderingMode)
}
