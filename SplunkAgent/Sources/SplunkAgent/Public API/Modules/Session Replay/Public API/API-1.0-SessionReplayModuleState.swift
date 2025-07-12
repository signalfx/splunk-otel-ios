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

/// An interface that provides read-only access to the current state of the Session Replay module.
///
/// The state properties reflect the final, effective settings being used by the module,
/// which are a combination of:
/// - Default SDK settings.
/// - The initial module configuration.
/// - Settings retrieved from a remote configuration source.
/// - User-defined preferences.
///
/// - Note: The values of these properties can change during the application's runtime.
///
/// ### Example ###
/// ```
/// if SplunkRum.shared.sessionReplay.state.isRecording {
///     print("Session Replay is currently recording.")
/// }
/// ```
public protocol SessionReplayModuleState {

    // MARK: - Recording

    /// The detailed recording status of the module.
    ///
    /// See ``SessionReplayStatus`` for all possible states.
    var status: SessionReplayStatus { get }

    /// A Boolean value indicating whether the module is currently recording.
    ///
    /// This is a convenience property. For more detailed information, check the ``status`` property.
    var isRecording: Bool { get }


    // MARK: - Rendering

    // Temporarily removed with Rendering Modes.

    // /// Indicates the rendering mode for capturing video.
    // var renderingMode: RenderingMode { get }
}