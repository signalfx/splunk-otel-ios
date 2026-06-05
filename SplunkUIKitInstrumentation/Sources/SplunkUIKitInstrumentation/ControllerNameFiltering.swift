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

/// Shared filtering for UIKit controller names produced by automatic UI instrumentation.
public enum ControllerNameFiltering {

    // MARK: - Private

    /// Internal iOS controllers that should not produce automatic UI instrumentation events.
    ///
    /// UIKit infrastructure controllers (keyboard, input, rotation) are listed
    /// without a module prefix because UIKit types are always reported as bare
    /// names by `String(describing: type(of:))`.
    ///
    /// SwiftUI infrastructure controllers are listed with the `SwiftUI.` module
    /// prefix because class-name sanitization only strips the host app's bundle
    /// prefix, not `SwiftUI.`. These names are verified against span data from an
    /// instrumented test app on iOS 26.2.
    private static let ignoredControllerTypeNames: Set<String> = [
        // UIKit infrastructure
        "UIApplicationRotationFollowingController",
        "UICompatibilityInputViewController",
        "UIEditingOverlayViewController",
        "UIInputWindowController",
        "UIKBSystemLayoutViewController",
        "UIPredictionViewController",
        "UISystemInputAssistantViewController",
        "UISystemInputViewController",
        "UISystemKeyboardDockController",
        "UITrackingElementWindowController",
        "UINavigationController",
        "UITabBarController",

        // SwiftUI navigation infrastructure: both prefixed (SwiftUI.X) and bare
        // (X) forms were observed in test runs; the prefixed form is matched here
        "SwiftUI.UIKitNavigationController",
        "SwiftUI.UIKitTabBarController",
        "SwiftUI.UIKitSplitViewController",
        "SwiftUI.UIKitInspectorSplitViewController",
        "SwiftUI.NotifyingMulticolumnSplitViewController",
        "SwiftUI.NotificationSendingSplitViewController",
        "SwiftUI.SplitViewNavigationController",
        "SwiftUI.TabHostingController",

        // SwiftUI non-navigation infrastructure
        "SwiftUI.PlatformAlertController",
        "SwiftUI.SwiftUISearchController"
    ]

    /// SwiftUI internal controllers whose type names include generic parameters.
    ///
    /// Prefix matching is required because the generic suffix varies at runtime
    /// depending on the view hierarchy.
    ///
    /// `NavigationStackHostingController<` and `PresentationHostingController<`
    /// were observed to be the two noisiest SwiftUI-internal generic types. They
    /// fire on every `NavigationStack` push/pop and every sheet/modal
    /// presentation, respectively.
    private static let ignoredControllerTypePrefixes: [String] = [
        "UIHostingController<",
        "NavigationStackHostingController<",
        "PresentationHostingController<",
        "StyleContextSplitViewNavigationController<"
    ]


    // MARK: - Public

    /// Returns whether the controller name should be filtered from automatic UI instrumentation.
    public static func shouldIgnore(controllerTypeName: String) -> Bool {
        let isExactMatch =
            ignoredControllerTypeNames
            .contains(controllerTypeName)
        let isPrefixMatch =
            ignoredControllerTypePrefixes
            .contains { controllerTypeName.hasPrefix($0) }
        return isExactMatch || isPrefixMatch
    }
}
