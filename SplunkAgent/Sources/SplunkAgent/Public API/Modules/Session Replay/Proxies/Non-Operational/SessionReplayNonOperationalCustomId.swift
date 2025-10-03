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

/// The class implementing the API for view element custom identifiers in non-operational mode.
///
/// This is especially the case when the module is stopped by remote configuration,
/// but we still need to keep the API available to the user.
final class SessionReplayNonOperationalCustomId: SessionReplayModuleCustomId {

    // MARK: - Internal

    /// The logger instance used for logging messages.
    private(set) unowned var logger: LogAgent


    // MARK: - Initialization

    /// Initializes a new instance of the `SessionReplayNonOperationalCustomId`.
    ///
    /// - Parameter logger: The `LogAgent` instance to use for logging.
    init(logger: LogAgent) {
        self.logger = logger
    }


    // MARK: - View Custom ID

    /// A non-operational implementation for getting or setting a custom view identifier.
    ///
    /// When the Session Replay module is disabled (e.g., via remote configuration), this
    /// property ensures the API remains available but performs no action. Accessing it
    /// will log a notice. The getter always returns `nil`.
    subscript(_: UIView) -> String? {
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

    /// Sets a custom identifier for a specific `UIView` instance.
    ///
    /// This method provides a fluent interface for assigning a custom ID.
    ///
    /// - Parameters:
    ///   - view: The `UIView` instance to identify.
    ///   - customId: The unique identifier string to assign. Pass `nil` to remove an existing ID.
    ///
    /// - Returns: The current `SessionReplayModuleCustomId` instance to maintain API compatibility.
    @discardableResult
    func set(_ view: UIView, _ customId: String?) -> any SessionReplayModuleCustomId {
        // Intentionally unused
        _ = view
        _ = customId

        logAccess(toApi: #function)

        return self
    }


    // MARK: - Logging

    /// Logs an access attempt to a non-operational API.
    ///
    /// - Parameter named: The name of the API being accessed.
    func logAccess(toApi named: String) {
        logger.log(level: .notice, isPrivate: false) {
            """
            Attempt to access the Custom ID API of a remotely disabled Session Replay module. \n
            API: `\(named)`
            """
        }
    }
}
