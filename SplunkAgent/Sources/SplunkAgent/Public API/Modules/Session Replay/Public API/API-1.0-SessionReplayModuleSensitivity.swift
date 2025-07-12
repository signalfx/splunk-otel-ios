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


import UIKit

/// An interface for managing which UI elements are masked (`sensitive`) during Session Replay recordings.
///
/// You can set sensitivity for individual view instances or for all instances of a specific `UIView` class.
/// The sensitivity settings are evaluated with the following precedence:
/// 1. **Instance Sensitivity:** A setting on a specific `UIView` instance always takes highest priority.
/// 2. **Class Sensitivity:** If no instance sensitivity is set, the setting for the view's class is used.
///
/// - Note: For convenience, some classes are sensitive by default: `UITextView`, `UITextField`, and `WKWebView`.
///
/// - Important: Sensitive elements are **masked locally** on the device. No sensitive data is ever
///              transferred over the network or stored in your dashboard.
///
/// ### Example ###
/// ```
/// // Mask all instances of a custom view class
/// SplunkRum.shared.sessionReplay.sensitivity[MyCustomSensitiveView.self] = true
///
/// // Unmask a specific instance of that class
/// let publicView = MyCustomSensitiveView()
/// SplunkRum.shared.sessionReplay.sensitivity[publicView] = false
/// ```
public protocol SessionReplayModuleSensitivity: AnyObject {

    // MARK: - View sensitivity

    /// Retrieves or sets the explicit sensitivity for a specific `UIView` instance.
    ///
    /// This setting overrides any class-level sensitivity.
    ///
    /// - Parameter view: The `UIView` instance to configure.
    /// - Returns: `true` if the instance is explicitly masked, `false` if explicitly unmasked,
    ///            or `nil` if its sensitivity is inherited from its class.
    subscript(view: UIView) -> Bool? { get set }

    /// Sets the explicit sensitivity for a specific `UIView` instance.
    ///
    /// - Note: This method provides the same functionality as the subscript and is included
    ///   for chaining convenience.
    ///
    /// - Parameters:
    ///   - view: The `UIView` instance to configure.
    ///   - sensitive: The sensitivity state to apply. Pass `true` to mask, `false` to unmask,
    ///                or `nil` to revert to class-level sensitivity.
    /// - Returns: The updated sensitivity object to allow for chaining.
    @discardableResult func set(_ view: UIView, _ sensitive: Bool?) -> any SessionReplayModuleSensitivity


    // MARK: - Class sensitivity

    /// Retrieves or sets the sensitivity for all instances of a given `UIView` class.
    ///
    /// - Parameter viewClass: The `UIView` class to configure (e.g., `UILabel.self`).
    /// - Returns: `true` if the class is explicitly masked, `false` if explicitly unmasked,
    ///            or `nil` if no class-level rule is set.
    subscript(viewClass: UIView.Type) -> Bool? { get set }

    /// Sets the sensitivity for all instances of a given `UIView` class.
    ///
    /// - Note: This method provides the same functionality as the subscript and is included
    ///   for chaining convenience.
    ///
    /// - Parameters:
    ///   - viewClass: The `UIView` class to configure.
    ///   - sensitive: The sensitivity state to apply. Pass `true` to mask, `false` to unmask,
    ///                or `nil` to remove the class-level rule.
    /// - Returns: The updated sensitivity object to allow for chaining.
    @discardableResult func set(_ viewClass: UIView.Type, _ sensitive: Bool?) -> any SessionReplayModuleSensitivity
}