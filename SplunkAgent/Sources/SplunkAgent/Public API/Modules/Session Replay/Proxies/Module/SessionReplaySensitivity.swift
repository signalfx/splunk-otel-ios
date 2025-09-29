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

internal import CiscoSessionReplay
import UIKit

/// The sensitivity object implements public API for the view element's sensitivity.
final class SessionReplaySensitivity: SessionReplayModuleSensitivity {

    // MARK: - Internal

    private(set) unowned var module: CiscoSessionReplay.SessionReplay


    // MARK: - Initialization

    init(for module: CiscoSessionReplay.SessionReplay) {
        self.module = module
    }


    // MARK: - View sensitivity

    /// Gets or sets the data sensitivity for a specific `UIView` instance.
    ///
    /// Setting this property overrides any class-level sensitivity defined for the view's type.
    ///
    /// - Parameters:
    ///   - view: The `UIView` instance to update or check on.
    ///
    /// - Returns: the Bool value of the sensitivity setting, or nil to defer to higher level settings.
    ///
    /// - Note: Setting the value to `true` marks the view as sensitive, causing it to be
    ///   masked during session replay. Setting it to `false` marks it as not sensitive.
    ///   Setting it to `nil` removes the instance-specific rule, reverting its behavior to
    ///   the class-level or default sensitivity setting.
    subscript(view: UIView) -> Bool? {
        get {
            module.sensitivity[view]
        }
        set {
            module.sensitivity[view] = newValue
        }
    }

    /// Sets the data sensitivity for a specific `UIView` instance.
    ///
    /// This method provides a fluent interface for configuring view sensitivity.
    ///
    /// - Parameters:
    ///   - view: The `UIView` instance to configure.
    ///   - sensitive: A boolean indicating if the view is sensitive (`true`), not sensitive (`false`),
    ///     or should revert to default behavior (`nil`).
    ///
    /// - Returns: The `SessionReplayModuleSensitivity` instance for chaining further configurations.
    @discardableResult
    func set(_ view: UIView, _ sensitive: Bool?) -> SessionReplayModuleSensitivity {
        self[view] = sensitive

        return self
    }


    // MARK: - Class sensitivity

    /// Gets or sets the default data sensitivity for all instances of a specific `UIView` class.
    ///
    /// This setting applies to all views of the specified type unless overridden by an
    /// instance-specific sensitivity setting.
    ///
    /// - Parameters:
    ///   - viewClass: The specific UIView class type to update or check on.
    ///
    /// - Returns: the Bool value of the sensitivity setting, or nil if no rule applied at the class level.
    ///
    /// - Note: Setting the value to `true` marks all views of this class as sensitive by default.
    ///   Setting it to `false` marks them as not sensitive. Setting it to `nil` removes the
    ///   class-level rule.
    subscript(viewClass: UIView.Type) -> Bool? {
        get {
            module.sensitivity[viewClass]
        }
        set {
            module.sensitivity[viewClass] = newValue
        }
    }

    /// Sets the default data sensitivity for all instances of a specific `UIView` class.
    ///
    /// This method provides a fluent interface for configuring class-level sensitivity.
    ///
    /// - Parameters:
    ///   - viewClass: The `UIView` class to configure.
    ///   - sensitive: A boolean indicating if views of this class are sensitive (`true`),
    ///     not sensitive (`false`), or should revert to default behavior (`nil`).
    ///
    /// - Returns: The `SessionReplayModuleSensitivity` instance for chaining further configurations.
    @discardableResult
    func set(_ viewClass: UIView.Type, _ sensitive: Bool?) -> SessionReplayModuleSensitivity {
        self[viewClass] = sensitive

        return self
    }
}
