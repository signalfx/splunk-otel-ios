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

internal import CiscoLogger
import UIKit

/// The class implementing public API for the view element's sensitivity in non-operational mode.
///
/// This is especially the case when the module is stopped by remote configuration,
/// but we still need to keep the API available to the user.
final class SessionReplayNonOperationalSensitivity: SessionReplayModuleSensitivity {

    // MARK: - Internal

    private(set) unowned var logger: LogAgent


    // MARK: - Initialization

    init(logger: LogAgent) {
        self.logger = logger
    }


    // MARK: - View sensitivity

    /// A non-operational implementation for getting or setting view instance sensitivity.
    ///
    /// When the Session Replay module is disabled, this property ensures the API remains
    /// available but performs no action. Accessing it will log a notice.
    /// The getter always returns `nil`, and the setter is a no-op.
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

    /// A non-operational implementation for setting view instance sensitivity.
    ///
    /// When the Session Replay module is disabled, calling this method will log a notice
    /// and will not change any sensitivity settings.
    ///
    /// - Parameters:
    ///   - view: The view that would have its sensitivity set.
    ///   - sensitive: The sensitivity flag that is being ignored.
    /// - Returns: The current ``SessionReplayModuleSensitivity`` instance to maintain API compatibility.
    @discardableResult public func set(_ view: UIView, _ sensitive: Bool?) -> SessionReplayModuleSensitivity {
        logAccess(toApi: #function)

        return self
    }


    // MARK: - Class sensitivity

    /// A non-operational implementation for getting or setting view class sensitivity.
    ///
    /// When the Session Replay module is disabled, this property ensures the API remains
    /// available but performs no action. Accessing it will log a notice.
    /// The getter always returns `nil`, and the setter is a no-op.
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

    /// A non-operational implementation for setting view class sensitivity.
    ///
    /// When the Session Replay module is disabled, calling this method will log a notice
    /// and will not change any sensitivity settings.
    ///
    /// - Parameters:
    ///   - viewClass: The view class that would have its sensitivity set.
    ///   - sensitive: The sensitivity flag that is being ignored.
    /// - Returns: The current ``SessionReplayModuleSensitivity`` instance to maintain API compatibility.
    @discardableResult public func set(_ viewClass: UIView.Type, _ sensitive: Bool?) -> SessionReplayModuleSensitivity {
        logAccess(toApi: #function)

        return self
    }


    // MARK: - Logging

    func logAccess(toApi named: String) {
        logger.log(level: .notice, isPrivate: false) {
            """
            Attempt to access the Sensitivity API of a remotely disabled Session Replay module. \n
            API: `\(named)`
            """
        }
    }
}
