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

internal import CiscoSessionReplay
import QuartzCore
import UIKit

public extension UIView {

    /// A custom identifier for this view, used for Session Replay and Interaction Tracking.
    ///
    /// Setting this ID allows you to uniquely identify and reference this specific view in your RUM data.
    /// This is particularly useful for masking or unmasking sensitive content in Session Replay or for
    /// tracking user interactions with specific UI elements.
    ///
    /// Assigning `nil` to this property removes any previously set identifier.
    ///
    /// ### Example ###
    /// ```
    /// let loginButton = UIButton()
    /// loginButton.splunkRumId = "login-button"
    ///
    /// // Later, you can retrieve it
    /// if let id = loginButton.splunkRumId {
    ///     print("Button ID: \(id)") // Prints "Button ID: login-button"
    /// }
    /// ```
    var splunkRumId: String? {
        get {
            SplunkRum.shared.sessionReplay.customIdentifiers[self]
        }
        set {
            SplunkRum.shared.sessionReplay.customIdentifiers[self] = newValue
            SplunkRum.shared.interactions.register(customId: newValue, for: ObjectIdentifier(self))
        }
    }
}