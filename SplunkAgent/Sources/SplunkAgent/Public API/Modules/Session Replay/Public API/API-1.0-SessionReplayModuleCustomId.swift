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

/// Defines a public API for the view element's custom id's.
public protocol SessionReplayModuleCustomId: AnyObject {

    // MARK: - View customId

    /// Retrieves or adds an element CustomId for the specified `UIView` instance.
    ///
    /// Assigning `nil` removes previously assigned value.
    ///
    /// - Parameter view: A view instance to add or remove custom id.
    ///
    /// - Returns: The view custom id
    subscript(_: UIView) -> String? { get set }

    /// Sets element custom id for the specified `UIView` instance.
    ///
    /// Assigning `nil` removes previously assigned custom id.
    ///
    /// - Parameters:
    ///   - view: A view instance for which to set the custom ID.
    ///   - customId: A new custom id.
    ///
    /// - Returns: The updated ``SessionReplayModuleCustomId`` object.
    @discardableResult
    func set(_ view: UIView, _ customId: String?) -> any SessionReplayModuleCustomId
}
