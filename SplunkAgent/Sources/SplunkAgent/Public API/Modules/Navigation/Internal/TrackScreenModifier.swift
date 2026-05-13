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

struct TrackScreenModifier: ViewModifier {

    // MARK: - Properties

    let screenName: String
    let attributes: [String: Any]?

    /// @State persists across redraws for the same view insertion, so the tracker
    /// retains its last-key state through body re-evaluations and modifier recreation.
    @State
    private var tracker = SwiftUIScreenTracker()


    // MARK: - ViewModifier methods

    func body(content: Content) -> some View {
        content
            .onAppear {
                // .onAppear fires multiple times during the SwiftUI view lifecycle
                // (redraws, tab switches, etc.). Deduplication lives here so that
                // Navigation.track(screen:) remains unconditional for explicit calls.
                tracker.trackIfChanged(screenName: screenName, attributes: attributes) {
                    SplunkRum.shared.navigation.track(screen: screenName, attributes: attributes)
                }
            }
    }
}
