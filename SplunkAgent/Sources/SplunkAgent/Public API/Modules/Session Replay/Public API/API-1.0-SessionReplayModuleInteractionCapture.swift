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

/// Defines a public API for controlling which detected interaction categories are captured.
///
/// All categories are enabled by default. Changes apply only to interactions received
/// after the corresponding property is updated.
public protocol SessionReplayModuleInteractionCapture: AnyObject {

    // MARK: - Categories

    /// Indicates whether soft keyboard interactions are captured.
    var isKeyboardEnabled: Bool { get set }

    /// Indicates whether pointer and touch interactions are captured.
    var isTouchEnabled: Bool { get set }

    /// Indicates whether recognized gesture interactions are captured.
    ///
    /// Rage tap interactions are controlled separately by ``isRageTapEnabled``.
    var isGestureEnabled: Bool { get set }

    /// Indicates whether focus-change interactions are captured.
    var isFocusEnabled: Bool { get set }

    /// Indicates whether rage tap interactions are captured.
    var isRageTapEnabled: Bool { get set }


    // MARK: - Bulk updates

    /// Enables capture for every configurable interaction category.
    func enableAll()

    /// Disables capture for every configurable interaction category.
    func disableAll()
}
