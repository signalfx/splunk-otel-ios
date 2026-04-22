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

extension Navigation {
    /// Internal iOS controllers that should not produce navigation events.
    private static let ignoredControllerTypeNames: Set<String> = [
        "UIApplicationRotationFollowingController",
        "UICompatibilityInputViewController",
        "UIInputWindowController",
        "UIKBSystemLayoutViewController",
        "UIPredictionViewController",
        "UISystemInputAssistantViewController",
        "UISystemInputViewController",
        "UISystemKeyboardDockController",
        "UINavigationController",
        "UITabBarController"
    ]

    /// SwiftUI internal controllers whose type names include generic
    /// parameters (e.g. `UIHostingController<ModifiedContent<...>>`).
    ///
    /// Prefix matching is required because the suffix varies at runtime.
    private static let ignoredControllerTypePrefixes: [String] = [
        "UIHostingController",
        "StyleContextSplitViewNavigationController"
    ]

    static func shouldIgnore(controllerTypeName: String) -> Bool {
        if ignoredControllerTypeNames.contains(controllerTypeName) {
            return true
        }
        return ignoredControllerTypePrefixes.contains { prefix in
            controllerTypeName.hasPrefix(prefix)
        }
    }
}
