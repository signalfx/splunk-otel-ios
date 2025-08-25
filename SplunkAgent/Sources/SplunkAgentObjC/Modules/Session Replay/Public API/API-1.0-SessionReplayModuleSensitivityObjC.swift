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

/// The Session Replay sensitivity class implements a public API for the view element's sensitivity.
@objc(SPLKSessionReplayModuleSensitivity)
public final class SessionReplayModuleSensitivityObjC: NSObject {

    // MARK: - Internal

    private unowned let owner: SplunkRumObjC


    // MARK: - View sensitivity

    /// Retrieves element sensitivity for the specified `UIView` instance.
    ///
    /// The method returns the view sensitivity as it is used by the Session Replay module.
    /// The sensitivity is calculated as a combination of the explicitly set sensitivity of the view instance
    /// and the sensitivity derived from the view's class sensitivity.
    ///
    /// - Parameter view: A `UIView` instance.
    ///
    /// - Returns: A `NSNumber` whose BOOL value returns the given view sensitivity.
    @objc(sensitivityForView:)
    public func sensitivity(for view: UIView) -> NSNumber? {
        guard let sensitive = owner.agent.sessionReplay.sensitivity[view] else {
            return nil
        }

        return NSNumber(value: sensitive)
    }

    /// Sets explicit element sensitivity for the specified `UIView` instance.
    ///
    /// - Parameters:
    ///   - sensitive: The explicit view sensitivity.
    ///               - Set `@YES` to flag the view instance as explicitly sensitive.
    ///               - Set `@NO` to flag the view instance as explicitly non-sensitive.
    ///               - Set `nil` to let the view instance sensitivity being derived from its class.
    ///
    ///   - view: A `UIView` instance to add or remove sensitivity preferences.
    @objc(setSensitivity:forView:)
    public func setSensitivity(_ sensitive: NSNumber?, for view: UIView) {
        guard let sensitive else {
            owner.agent.sessionReplay.sensitivity[view] = nil

            return
        }

        owner.agent.sessionReplay.sensitivity[view] = sensitive.boolValue
    }


    // MARK: - Class sensitivity

    /// Retrieves sensitivity for the specified `UIView` class or its descendant.
    ///
    /// The method returns the view class sensitivity as it is used by the Session Replay module.
    /// The sensitivity is calculated as a combination of the explicitly set sensitivity of the view class
    /// and the sensitivity derived from the view class parents sensitivity.
    ///
    /// - Parameter view: A `UIView` class or its descendant.
    ///
    /// - Returns: A `NSNumber` whose BOOL value returns the given view class sensitivity.
    @objc(sensitivityForViewClass:)
    public func sensitivity(for viewClass: UIView.Type) -> NSNumber? {
        guard let sensitive = owner.agent.sessionReplay.sensitivity[viewClass] else {
            return nil
        }

        return NSNumber(value: sensitive)
    }

    /// Sets explicit sensitivity for the specified `UIView` class or its descendant.
    ///
    /// - Parameters:
    ///   - sensitive: The explicit class sensitivity.
    ///               - Set `@YES` to flag the view class as explicitly sensitive.
    ///               - Set `@NO` to flag the view class as explicitly non-sensitive.
    ///               - Set `nil` to let the view class sensitivity being derived from its **parent** class.
    ///
    ///   - viewClass: A `UIView` class or its descendant to set the sensitivity.
    @objc(setSensitivity:forViewClass:)
    public func setSensitivity(_ sensitive: NSNumber?, for viewClass: UIView.Type) {
        guard let sensitive else {
            owner.agent.sessionReplay.sensitivity[viewClass] = nil

            return
        }

        owner.agent.sessionReplay.sensitivity[viewClass] = sensitive.boolValue
    }


    // MARK: - Initialization

    init(for owner: SplunkRumObjC) {
        self.owner = owner
    }
}
