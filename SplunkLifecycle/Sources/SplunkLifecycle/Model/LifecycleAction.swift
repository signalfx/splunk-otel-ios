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

/// A supported UI lifecycle action.
public enum LifecycleAction: String, CaseIterable, Codable, Hashable, Sendable {
    /// A `UIViewController` loaded its view.
    case viewCreated = "view_created"

    /// A `UIViewController` appeared.
    case resumed

    /// A `UIViewController` disappeared.
    case stopped


    // MARK: - Static constants

    /// The default low-volume lifecycle event set.
    public static let mainLifecycleEvents: Set<LifecycleAction> = [
        .viewCreated,
        .resumed,
        .stopped
    ]
}
