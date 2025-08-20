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

import Foundation
import SplunkAgent
import UIKit

@objc
public extension UIView {

    /// Element custom ID for the specified `UIView` instance.
    ///
    /// Assigning `nil` removes previously assigned custom ID.
    @objc(splk_splunkRumID)
    var splunkCustomId: String? {
        get {
            splunkRumId
        }
        set {
            splunkRumId = newValue
        }
    }
}
