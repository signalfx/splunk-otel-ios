//
/*
Copyright 2026 Splunk Inc.

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

/// Objective-C constants for supported lifecycle action strings.
@objc(SPLKLifecycleAction)
public final class LifecycleActionObjC: NSObject {

    // MARK: - Lifecycle actions

    /// A `UIViewController` loaded its view.
    @objc
    public static let viewCreated: NSString = "view_created"

    /// A `UIViewController` appeared.
    @objc
    public static let resumed: NSString = "resumed"

    /// A `UIViewController` disappeared.
    @objc
    public static let stopped: NSString = "stopped"


    // MARK: - Initialization

    /// Initialization is hidden from the public API
    /// as we only need to work with the class type.
    override init() {}
}


extension LifecycleActionObjC {

    // MARK: - Defaults

    static var defaultAllowedEvents: [String] {
        [
            viewCreated as String,
            resumed as String,
            stopped as String
        ]
    }
}
