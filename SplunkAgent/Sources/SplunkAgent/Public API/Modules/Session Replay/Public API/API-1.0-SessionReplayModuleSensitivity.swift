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


import UIKit

/// Defines a public API for the view element's sensitivity.
///
/// The resulting instance sensitivity consists of setting the sensitivity for the class
/// or its ancestors and explicitly setting on the custom view instance.
///
/// If multiple sensitivity settings have been applied to an instance, either directly
/// or indirectly through inheritance, they are evaluated using the following
/// sequence: `Instance`, `Class`. The setting for the instance always
/// takes precedence over other methods.
///
/// - Note: For convenience, some classes are set sensitive by default:
///      `UITextView`, `UITextField` and `WKWebView`.
///
/// - Important: Sensitive elements are **hidden locally** on the device.
///     No sensitive data are transferred over the network and stored in the dashboard.
public protocol SessionReplayModuleSensitivity: AnyObject {

    // MARK: - View sensitivity

    /// Retrieves or adds an element sensitivity for the specified `UIView` instance.
    ///
    /// Assigning `nil` removes previously assigned explicit sensitivity.
    ///
    /// - Parameter view: A view instance to add or remove sensitivity preferences.
    ///
    /// - Returns: The view sensitivity as combination of instance and class/protocol defined
    ///     sensitivity. If the view is sensitive, then return `true`. If it is
    ///     non-sensitive, then return `false`. In all other states, it returns `nil`.
    subscript(view: UIView) -> Bool? { get set }

    /// Sets element sensitivity for the specified `UIView` instance.
    ///
    /// Assigning `nil` removes previously assigned explicit sensitivity.
    ///
    /// - Parameters:
    ///   - view: A view instance to add or remove sensitivity preferences.
    ///   - sensitive: A new state of view instance sensitivity.
    ///
    /// - Returns: The updated sensitivity object.
    @discardableResult func set(_ view: UIView, _ sensitive: Bool?) -> any SessionReplayModuleSensitivity


    // MARK: - Class sensitivity

    /// Retrieves or adds sensitivity for the specified member of `UIView` class.
    ///
    /// Assigning `nil` removes previously assigned explicit sensitivity.
    ///
    /// - Parameter viewClass: A view class to add or remove sensitivity preferences.
    ///
    /// - Returns: The view class sensitivity. If the class is explicitly marked
    ///     as sensitive, then return `true`. If it is explicitly marked
    ///     as non-sensitive, then return `false`. In all other states,
    ///     it returns `nil`.
    subscript(viewClass: UIView.Type) -> Bool? { get set }

    /// Sets sensitivity for the specified member of `UIView` class.
    ///
    /// Assigning `nil` removes previously assigned explicit sensitivity.
    ///
    /// - Parameters:
    ///   - viewClass: A view class to add or remove sensitivity preferences.
    ///   - sensitive: A new state of view class sensitivity.
    ///
    /// - Returns: The updated sensitivity object.
    @discardableResult func set(_ viewClass: UIView.Type, _ sensitive: Bool?) -> any SessionReplayModuleSensitivity
}
