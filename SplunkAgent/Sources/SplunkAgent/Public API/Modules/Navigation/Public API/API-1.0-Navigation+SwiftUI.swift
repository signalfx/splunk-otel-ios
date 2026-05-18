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

import SwiftUI

extension View {

    // MARK: - Screen tracking (SwiftUI)

    /// Tracks the screen name when this view appears.
    ///
    /// Use this modifier to manually set the current screen name for navigation tracking
    /// in SwiftUI views. The screen name is reported each time the view appears.
    ///
    /// ```swift
    /// struct ProductDetailView: View {
    ///     var body: some View {
    ///         VStack { ... }
    ///             .trackScreen("ProductDetail")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter name: The screen name to track.
    ///
    /// - Returns: The `View` with screen tracking applied.
    public func trackScreen(_ name: String) -> some View {
        modifier(TrackScreenModifier(screenName: name, attributes: nil))
    }

    /// Tracks the screen name with additional attributes when this view appears.
    ///
    /// ```swift
    /// struct ProductDetailView: View {
    ///     let productId: String
    ///
    ///     var body: some View {
    ///         VStack { ... }
    ///             .trackScreen("ProductDetail", attributes: [
    ///                 "product.id": productId
    ///             ])
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - name: The screen name to track.
    ///   - attributes: Optional attributes associated with the screen tracking event.
    ///     Supported value types: `String`, `Int`, `Double`, `Bool`, and arrays of those types.
    ///     Other types are converted to their string representation.
    ///
    /// - Returns: The `View` with screen tracking applied.
    public func trackScreen(_ name: String, attributes: [String: Any]?) -> some View {
        modifier(TrackScreenModifier(screenName: name, attributes: attributes))
    }
}
