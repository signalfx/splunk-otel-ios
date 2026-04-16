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

import SplunkAgent
import SwiftUI

struct NavigationTrackingDemoView: View {

    var body: some View {
        List {
            NavigationLink(destination: BasicTrackingView()) {
                Text("Basic (no attributes)")
            }
            NavigationLink(destination: AttributesTrackingView()) {
                Text("With custom attributes")
            }
        }
        .navigationTitle("Navigation Tracking")
        .trackScreen("NavigationTrackingDemo")
    }
}


// MARK: - Code snippet

private struct CodeSnippetView: View {

    let code: String

    var body: some View {
        Text(code)
            .font(.system(.caption, design: .monospaced))
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
    }
}


// MARK: - Demo screens

private struct BasicTrackingView: View {

    var body: some View {
        VStack(spacing: 16) {
            DemoHeaderView()
            CodeSnippetView(code: """
                .trackScreen("BasicTracking")
                """)
            Spacer()
        }
        .padding()
        .navigationTitle("Basic Tracking")
        .trackScreen("BasicTracking")
    }
}

private struct AttributesTrackingView: View {

    var body: some View {
        VStack(spacing: 16) {
            DemoHeaderView()
            CodeSnippetView(code: """
                .trackScreen(
                    "AttributesTracking",
                    attributes: [
                        "demo.feature": "trackScreen",
                        "demo.attributes": true
                    ]
                )
                """)
            Spacer()
        }
        .padding()
        .navigationTitle("Attributes Tracking")
        .trackScreen(
            "AttributesTracking",
            attributes: [
                "demo.feature": "trackScreen",
                "demo.attributes": true
            ]
        )
    }
}
