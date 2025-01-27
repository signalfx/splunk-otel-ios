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


@_implementationOnly import SplunkLogger
import UIKit

/// The class implementing public API for the view element's sensitivity in non-operational mode.
///
/// This is especially the case when the module is stopped by remote configuration,
/// but we still need to keep the API available to the user.
final class SessionReplayNonOperationalSensitivity: SessionReplayModuleSensitivity {

    // MARK: - Internal

    private(set) unowned var internalLogger: InternalLogger


    // MARK: - Initialization

    init(logger: InternalLogger) {
        internalLogger = logger
    }


    // MARK: - View sensitivity

    public subscript(view: UIView) -> Bool? {
        get {
            logAccess(toApi: #function)

            return nil
        }

        // swiftlint:disable unused_setter_value
        set {
            logAccess(toApi: #function)
        }
        // swiftlint:enable unused_setter_value
    }

    @discardableResult public func set(_ view: UIView, _ sensitive: Bool?) -> SessionReplayModuleSensitivity {
        logAccess(toApi: #function)

        return self
    }


    // MARK: - Class sensitivity

    public subscript(viewClass: UIView.Type) -> Bool? {
        get {
            logAccess(toApi: #function)

            return nil
        }

        // swiftlint:disable unused_setter_value
        set {
            logAccess(toApi: #function)
        }
        // swiftlint:enable unused_setter_value
    }

    @discardableResult public func set(_ viewClass: UIView.Type, _ sensitive: Bool?) -> SessionReplayModuleSensitivity {
        logAccess(toApi: #function)

        return self
    }


    // MARK: - Logging

    func logAccess(toApi named: String) {
        internalLogger.log(level: .notice) {
            """
            Attempt to access the Sensitivity API of a remotely disabled Session Replay module. \n
            API: `\(named)`
            """
        }
    }
}
