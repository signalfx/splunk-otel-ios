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

internal import CiscoSessionReplay
import UIKit

// Implements the public API for assigning custom identifiers to view elements
final class SessionReplayCustomId: SessionReplayModuleCustomId {

    // MARK: - View sensitivity

    // Gets or sets a custom identifier for a specific `UIView` instance
    //
    // This identifier can be used to uniquely identify UI elements in the session replay
    // data, which is useful for analysis and debugging
    //
    // - Note: Setting the value to `nil` will remove any previously set custom identifier
    //   from the view
    subscript(view: UIView) -> String? {
        get {
            view.customId
        }
        set {
            view.customId = newValue
        }
    }

    // Sets a custom identifier for a specific `UIView` instance
    //
    // This method provides a fluent interface for assigning a custom ID
    //
    // - Parameters:
    //   - view: The `UIView` instance to identify
    //   - customId: The unique identifier string to assign. Pass `nil` to remove an existing ID
    // - Returns: The `SessionReplayModuleCustomId` instance for chaining further configurations
    @discardableResult func set(_ view: UIView, _ customId: String?) -> SessionReplayModuleCustomId {
        self[view] = customId

        return self
    }
}
