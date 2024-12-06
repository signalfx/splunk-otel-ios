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

struct SensitivityModifier: ViewModifier {

    // MARK: - Public

    let sensitive: Bool


    // MARK: - ViewModifier methods

    func body(content: Content) -> some View {
        if sensitive {
            content
                .background(SmartlookSensitiveView(sensitive: sensitive))
        } else {
            content
        }
    }
}


private struct SmartlookSensitiveView: UIViewRepresentable {

    // MARK: - Public

    var sensitive: Bool


    // MARK: - UIViewRepresentable methods

    func makeUIView(context: Context) -> UIView {
        return SLSensitiveView()
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        uiView.srSensitive = sensitive
    }
}


// MARK: - Helper classes

class SLSensitiveView: UIView {}
