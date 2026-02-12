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
import WebKit

struct WebViewSectionView: View {
    let caption: String
    let webView: WKWebView
    let backgroundColor: Color
    let buttons: [WebDemoButton]

    var body: some View {
        VStack {
            Text(caption)
                .font(.footnote)
                .padding(.top)

            WebViewRepresentable(webView: webView)
                .frame(height: buttons.count == 2 ? 200 : 150)
                .background(Color(red: 0.95, green: 0.95, blue: 0.98)) // Light gray with blue tint
                .cornerRadius(8)
                .border(Color.gray)
                .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(buttons.indices, id: \.self) { index in
                    buttons[index]
                    if buttons.count > 1, index < buttons.count - 1 {
                        Text("—")
                            .font(.body)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(backgroundColor)
        .cornerRadius(8)
        .padding()
    }
}
