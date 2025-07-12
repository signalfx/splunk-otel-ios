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

import Combine

/// An interface for controlling Session Replay recordings, including starting/stopping,
/// managing view sensitivity, and setting preferences.
public protocol SessionReplayModule: ObservableObject {

    // MARK: - Sensitivity

    /// An object for managing the masking of sensitive views.
    ///
    /// See ``SessionReplayModuleSensitivity`` for more details.
    var sensitivity: SessionReplayModuleSensitivity { get }


    // MARK: - Custom id

    /// An object for assigning custom identifiers to views for tracking and masking purposes.
    ///
    /// See ``SessionReplayModuleCustomId`` for more details.
    var customIdentifiers: SessionReplayModuleCustomId { get }


    // MARK: - State

    /// An object that provides read-only access to the current state of the Session Replay module.
    ///
    /// See ``SessionReplayModuleState`` for more details.
    var state: SessionReplayModuleState { get }


    // MARK: - Module preferences

    /// The preferences that control the behavior of Session Replay recordings.
    ///
    /// See ``SessionReplayModulePreferences`` for available options.
    var preferences: SessionReplayModulePreferences { get set }

    /// Sets the preferences for Session Replay recordings.
    ///
    /// - Parameter preferences: The ``SessionReplayModulePreferences`` to apply.
    /// - Returns: The `SessionReplayModule` instance to allow for chaining.
    @discardableResult func preferences(_ preferences: SessionReplayModulePreferences) -> any SessionReplayModule


    // MARK: - Recording management

    /// Starts a new Session Replay recording if one is not already in progress.
    ///
    /// ### Example ###
    /// ```
    /// SplunkRum.shared.sessionReplay.start()
    /// ```
    /// - Returns: The `SessionReplayModule` instance to allow for chaining.
    @discardableResult func start() -> any SessionReplayModule

    /// Stops the current Session Replay recording.
    ///
    /// - Note: You do not need to call this method when the application is closed by the user;
    ///         the module handles this automatically.
    ///
    /// ### Example ###
    /// ```
    /// SplunkRum.shared.sessionReplay.stop()
    /// ```
    /// - Returns: The `SessionReplayModule` instance to allow for chaining.
    @discardableResult func stop() -> any SessionReplayModule


    // MARK: - Recording masks

    /// A view that overlays the entire screen to mask sensitive content during recordings.
    ///
    /// See ``RecordingMask`` for more details.
    var recordingMask: RecordingMask? { get set }

    /// Sets a custom view to overlay the screen and mask sensitive content.
    ///
    /// - Parameter recordingMask: A ``RecordingMask`` to apply. Pass `nil` to remove the mask.
    /// - Returns: The `SessionReplayModule` instance to allow for chaining.
    @discardableResult func recordingMask(_ recordingMask: RecordingMask?) -> any SessionReplayModule
}