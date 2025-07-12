/*
Copyright 2024 Splunk Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

import UIKit

/// An interface for managing custom identifiers for `UIView` instances.
///
/// Use this API to assign unique, human-readable IDs to your views. These identifiers
/// can be used to reference specific views for tracking or masking in Session Replay.
///
/// ### Example ###
/// ```
/// let loginButton = UIButton()
/// SplunkRum.shared.sessionReplay.customIdentifiers[loginButton] = "login-button"
/// ```
public protocol SessionReplayModuleCustomId: AnyObject {

    // MARK: - View customId

    /// Retrieves or sets a custom identifier for a specific `UIView`.
    ///
    /// Setting a value to `nil` removes any previously assigned identifier for the view.
    ///
    /// - Parameter view: The `UIView` instance to identify.
    /// - Returns: The custom identifier as a `String`, or `nil` if none is set.
    subscript(view: UIView) -> String? { get set }

    /// Sets a custom identifier for a specific `UIView` instance.
    ///
    /// - Note: This method provides the same functionality as the subscript and is included
    ///   for chaining convenience.
    ///
    /// - Parameters:
    ///   - view: The `UIView` instance to identify.
    ///   - customId: The custom identifier to assign. Pass `nil` to remove an existing identifier.
    /// - Returns: The updated `SessionReplayModuleCustomId` object to allow for chaining.
    @discardableResult func set(_ view: UIView, _ customId: String?) -> any SessionReplayModuleCustomId
}