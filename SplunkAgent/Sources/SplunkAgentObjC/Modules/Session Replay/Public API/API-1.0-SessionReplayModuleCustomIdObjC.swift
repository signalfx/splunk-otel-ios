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

/// The Session Replay custom ID object implements a public API for the view element's custom id's.
@objc(SPLKSessionReplayModuleCustomID)
public final class SessionReplayModuleCustomIdObjC: NSObject {

    // MARK: - Internal

    private unowned let owner: SplunkRumObjC


    // MARK: - Custom ID

    /// Retrieves element custom ID for the specified `UIView` instance.
    ///
    /// - Parameter view: A `UIView` instance.
    ///
    /// - Returns: The view's custom ID.
    @objc(customIDForView:)
    public func customId(for view: UIView) -> String? {
        owner.agent.sessionReplay.customIdentifiers[view]
    }

    /// Sets element custom ID for the specified `UIView` instance.
    ///
    /// Assigning `nil` removes previously assigned custom ID.
    ///
    /// - Parameters:
    ///   - customId: A `NSString` with a new custom ID.
    ///   - view: A `UIView` instance to add or remove custom ID.
    @objc(setCustomID:forView:)
    public func setCustomId(_ customId: String?, for view: UIView) {
        owner.agent.sessionReplay.customIdentifiers[view] = customId
    }


    // MARK: - Initialization

    init(for owner: SplunkRumObjC) {
        self.owner = owner
    }
}
