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
import QuartzCore
import UIKit

public extension UIView {

    /// A Boolean value that controls whether this view and its subviews are masked during Session Replay recordings.
    ///
    /// This property has three states:
    /// - `true`: Masks the view, treating it as sensitive.
    /// - `false`: Unmasks the view, treating it as not sensitive. This can override a parent's sensitive setting.
    /// - `nil`: The view inherits its sensitivity from its parent. Setting this property to `nil` reverts it to the default inherited behavior.
    ///
    /// ### Example ###
    /// ```
    /// // Mask a view containing sensitive user information
    /// let userProfileView = UIView()
    /// userProfileView.srSensitive = true
    ///
    /// // Unmask a specific public label within that sensitive view
    /// let publicLabel = UILabel()
    /// userProfileView.addSubview(publicLabel)
    /// publicLabel.srSensitive = false
    /// ```
    var srSensitive: Bool? {
        get {
            SplunkRum.shared.sessionReplay.sensitivity[self]
        }
        set {
            SplunkRum.shared.sessionReplay.sensitivity[self] = newValue
        }
    }
}