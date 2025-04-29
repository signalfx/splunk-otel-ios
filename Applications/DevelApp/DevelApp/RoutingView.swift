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

struct RoutingView: View {
    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: CrashDemoView()) {
                    Text("Crash Demo")
                }
                NavigationLink(destination: SessionReplayDemoView()) {
                    Text("Session Replay Demo")
                }
                NavigationLink(destination: WebViewDemoView()) {
                    Text("WebView Demo")
                }
                NavigationLink(destination: TemplateView()) {
                    Text("Template for New Screens")
                }
            }
            .navigationTitle("Demo Screens")
        }
    }
}
