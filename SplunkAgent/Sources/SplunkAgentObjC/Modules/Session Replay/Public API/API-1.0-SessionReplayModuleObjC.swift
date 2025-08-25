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

/// The class implements a public API for the Session Replay module.
@objc(SPLKSessionReplayModule)
public final class SessionReplayModuleObjC: NSObject {

    // MARK: - Internal

    private unowned let owner: SplunkRumObjC


    // MARK: - Sensitivity

    /// An object that holds and manages view elements sensitivity.
    @objc
    public private(set) lazy var sensitivity = SessionReplayModuleSensitivityObjC(for: owner)


    // MARK: - Custom ID

    /// An object that holds and manages the view elements' custom IDs.
    @objc
    public private(set) lazy var customIdentifiers = SessionReplayModuleCustomIdObjC(for: owner)

    // MARK: - State

    /// An object that reflects the current state and settings used for the recording.
    @objc
    public private(set) lazy var state = SessionReplayModuleStateObjC(for: owner)


    // MARK: - Module preferences

    /// An object that holds preferred settings for the recording.
    @objc
    public private(set) lazy var preferences = SessionReplayModulePreferencesObjC(for: owner)


    // MARK: - Recording management

    /// Starts recording.
    ///
    /// If the recording is already running, then it does nothing.
    @objc
    public func start() {
        owner.agent.sessionReplay.start()
    }

    /// Stops the currently running recording.
    ///
    /// If the recording is not running, then it does nothing.
    ///
    /// This method is primarily used to pause the recording and does not need to call
    /// when the application exits. If the application is closed by the user,
    /// the module itself will call it.
    @objc
    public func stop() {
        owner.agent.sessionReplay.stop()
    }


    // MARK: - Recording masks

    /// The recording mask, covers possibly sensitive areas.
    @objc
    public var recordingMask: RecordingMaskObjC? {
        get {
            let mask = owner.agent.sessionReplay.recordingMask

            return RecordingMaskObjC(with: mask)
        }
        set {
            let mask = newValue?.recordingMask
            owner.agent.sessionReplay.recordingMask = mask
        }
    }


    // MARK: - Initialization

    init(for owner: SplunkRumObjC) {
        self.owner = owner
    }
}
