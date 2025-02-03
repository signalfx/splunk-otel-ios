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

@_implementationOnly import SplunkLogger
@_implementationOnly import CiscoSessionReplay

/// The class implementing Session Replay public API.
final class SessionReplay: SessionReplayModule {

    // MARK: - Internal

    unowned let module: CiscoSessionReplay.SessionReplay


    // MARK: - Private

    // Temporarily removed with Rendering Modes.
    // var internalPreferences: (any SessionReplayModulePreferences)?

    private let internalLogger: InternalLogger


    // MARK: - Test support

    var newSessionsCount = 0


    // MARK: - Initialization

    init(for module: CiscoSessionReplay.SessionReplay) {
        self.module = module
        internalLogger = InternalLogger(configuration: .agent(category: "SessionReplay Module"))

        // Monitor session changes in the agent.
        hookToAgentLifecycle()
    }


    // MARK: - Module preferences

    // Temporarily removed with Rendering Modes.

    // swiftformat:disable indent

    /*

    lazy var preferences: any SessionReplayModulePreferences = SessionReplayPreferences(for: module) {
        didSet {
            // Link preferences with module instance
            (preferences as? SessionReplayPreferences)?.module = module

            // Pass changes into the module
            module.preferences = SplunkSessionReplayPreferences(preferences: preferences)
        }
    }

    @discardableResult func preferences(_ preferences: SessionReplayModulePreferences) -> any SessionReplayModule {
        self.preferences = preferences

        return self
    }
    */

    // swiftformat:enable indent


    // MARK: - Sensitivity

    private(set) lazy var sensitivity: any SessionReplayModuleSensitivity = SessionReplaySensitivity(for: module)


    // MARK: - State

    private(set) lazy var state: any SessionReplayModuleState = SessionReplayState(for: module)
}


extension SessionReplay {

    // MARK: - Agent session lifecycle

    private func hookToAgentLifecycle() {
        // Current session will be changed
        _ = NotificationCenter.default.addObserver(
            forName: DefaultSession.sessionDidResetNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in

            // If the session has been changed during the agent run, we need to pass this change
            // to the module. Opening a new session in the module closes the old one and ends the current record.
            //
            // This ensures the current record will end before a new session exists in the agent.
            // self?.module.openNewSession()

            // Log the change for easier debugging
            self?.internalLogger.log(level: .info) {
                "The current record from the Session Replay module will be split due to a session change."
            }

            // Record this operation for unit test purposes
            self?.newSessionsCount += 1
        }
    }
}
