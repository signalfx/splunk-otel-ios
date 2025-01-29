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

/// Defines a public API for the current state of the Session Replay.
///
/// The individual properties are a combination of:
/// - Default settings.
/// - Initial default configuration.
/// - Settings retrieved from the backend.
/// - Preferred behavior.
///
/// - Note: The states of individual properties in this class can
///         and usually also change during the application's runtime.
public protocol SessionReplayModuleState {

    // MARK: - Recording

    /// A `Status` of module recording.
    ///
    /// The default value is `.notRecording(.notStarted)`.
    var status: SessionReplayStatus { get }

    /// Indicates whether module is recording.
    ///
    /// For detailed info about status, see ``status``.
    var isRecording: Bool { get }


    // MARK: - Rendering

    // Temporarily removed with Rendering Modes.

    // /// Indicates the rendering mode for capturing video.
    // var renderingMode: RenderingMode { get }
}
