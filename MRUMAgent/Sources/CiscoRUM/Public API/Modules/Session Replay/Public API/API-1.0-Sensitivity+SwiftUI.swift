//
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

import SwiftUI

public extension View {

    // MARK: - View sensitivity (SwiftUI)

    /// Sets an recording sensitivity for the specified `View`.
    ///
    /// To set the sensitivity of Views that encapsulate native UIKit elements,
    /// you must first set their sensitivity using the UIKit methods
    /// and then hide the View using this modifier.
    ///
    /// - Parameter sensitive: A new state of element sensitivity.
    ///
    /// - Returns: The `View` with defined sensitivity for recording in Session Replay module.
    func sessionReplaySensitive(_ sensitive: Bool = true) -> some View {
        return modifier(SensitivityModifier(sensitive: sensitive))
    }
}
