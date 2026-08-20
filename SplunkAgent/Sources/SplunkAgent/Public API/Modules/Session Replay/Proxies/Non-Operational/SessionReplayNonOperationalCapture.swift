//
/*
Copyright 2026 Splunk Inc.

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

internal import CiscoLogger

/// The class implementing interaction capture API in non-operational mode.
final class SessionReplayNonOperationalCapture: SessionReplayModuleInteractionCapture {

    // MARK: - Private

    private let logger: LogAgent


    // MARK: - Initialization

    init(logger: LogAgent) {
        self.logger = logger
    }


    // MARK: - Categories

    // swiftlint:disable unused_setter_value

    var isKeyboardEnabled: Bool {
        get {
            logAccess(toApi: #function)

            return false
        }
        set {
            logAccess(toApi: #function)
        }
    }

    var isTouchEnabled: Bool {
        get {
            logAccess(toApi: #function)

            return false
        }
        set {
            logAccess(toApi: #function)
        }
    }

    var isGestureEnabled: Bool {
        get {
            logAccess(toApi: #function)

            return false
        }
        set {
            logAccess(toApi: #function)
        }
    }

    var isFocusEnabled: Bool {
        get {
            logAccess(toApi: #function)

            return false
        }
        set {
            logAccess(toApi: #function)
        }
    }

    var isRageTapEnabled: Bool {
        get {
            logAccess(toApi: #function)

            return false
        }
        set {
            logAccess(toApi: #function)
        }
    }

    // swiftlint:enable unused_setter_value


    // MARK: - Bulk updates

    func enableAll() {
        logAccess(toApi: #function)
    }

    func disableAll() {
        logAccess(toApi: #function)
    }


    // MARK: - Logging

    func logAccess(toApi named: String) {
        logger.log(level: .notice, isPrivate: false) {
            """
            Attempt to access the Interaction Capture API of a remotely disabled Session Replay module. \n
            API: `\(named)`
            """
        }
    }
}
