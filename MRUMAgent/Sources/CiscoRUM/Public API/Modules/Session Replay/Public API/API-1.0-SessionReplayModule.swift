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

import Combine

/// Defines a public API for the Session Replay module.
public protocol SessionReplayModule: ObservableObject {

    // MARK: - Sensitivity

    /// An object that holds and manages view elements sensitivity.
    var sensitivity: SessionReplayModuleSensitivity { get }


    // MARK: - State

    /// An object that reflects the current state and settings used for the recording.
    var state: SessionReplayModuleState { get }


    // MARK: - Module preferences

    // Temporarily removed with Rendering Modes.

    // swiftformat:disable indent

    /*

    /// An object that holds preferred settings for the recording.
    var preferences: SessionReplayModulePreferences { get set }

    /// Sets preferred settings for the recording.
    ///
    /// - Parameter preferences: The preferred settings for the recording.
    ///
    /// - Returns: The actual `SessionReplay` instance.
    @discardableResult func preferences(_ preferences: SessionReplayModulePreferences) -> any SessionReplayModule
     */

    // swiftformat:enable indent


    // MARK: - Recording management

    /// Starts recording.
    ///
    /// If the recording is already running, then it does nothing.
    ///
    /// - Returns: The actual `SessionReplay` instance.
    @discardableResult func start() -> any SessionReplayModule

    /// Stops the currently running recording.
    ///
    /// If the recording is not running, then it does nothing.
    ///
    /// This method is primarily used to pause the recording and does not need to call
    /// when the application exits. If the application is closed by the user,
    /// the module itself will call it.
    ///
    /// - Returns: The actual `SessionReplay` instance.
    @discardableResult func stop() -> any SessionReplayModule


    // MARK: - Recording masks

    /// The recording mask, covers possibly sensitive areas.
    var recordingMask: RecordingMask? { get set }

    /// Sets a recording mask that covers possibly sensitive areas.
    ///
    /// - Parameter recordingMask: The predefined recording mask for recording.
    ///
    /// - Returns: The actual `SessionReplay` instance.
    @discardableResult func recordingMask(_ recordingMask: RecordingMask?) -> any SessionReplayModule
}
