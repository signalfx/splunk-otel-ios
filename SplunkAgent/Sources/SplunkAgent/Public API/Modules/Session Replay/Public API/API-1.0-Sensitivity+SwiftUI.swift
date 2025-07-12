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

import SwiftUI

public extension View {

    // MARK: - View sensitivity (SwiftUI)

    /// Masks this view and its subviews during Session Replay recordings to protect sensitive information.
    ///
    /// By default, this modifier treats the view as sensitive and applies a masking effect.
    ///
    /// - Note: This modifier only affects SwiftUI views. If your view wraps a UIKit element
    ///   (e.g., using `UIViewRepresentable`), you must also configure the sensitivity
    ///   of the underlying `UIView` for masking to work correctly.
    ///
    /// - Parameter sensitive: A Boolean value that determines whether the view should be masked.
    ///   Defaults to `true`.
    /// - Returns: A view that is configured for sensitivity in Session Replay recordings.
    ///
    /// ### Example ###
    /// ```
    /// VStack {
    ///     Text("This is public information.")
    ///     TextField("Password", text: $password)
    ///         .sessionReplaySensitive() // This TextField will be masked
    /// }
    /// ```
    func sessionReplaySensitive(_ sensitive: Bool = true) -> some View {
        return modifier(SensitivityModifier(sensitive: sensitive))
    }
}