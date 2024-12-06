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

struct ContentView: View {
    
    @State private var isTriggered: Bool = false

    var body: some View {
        ScrollView {
            VStack {
                DemoTitle("ANR (App Not Responding) demo")
                Text("threshold for reporting: 2 seconds")
                Text("maxANRDuration: 10 seconds")
                    .padding(.bottom, 40)
                Spacer()
                DemoSleepButton(.short, $isTriggered)
                DemoSleepButton(.medium, $isTriggered)
                DemoSleepButton(.long, $isTriggered)
                Spacer()
                /// Unlike the "Condition <ANR|normal>" text below, this heartbeat stopping during an ANR demo is not faked. It stops beating because the main thread is actually stalled with the sleep function.
                BeatingHeart()
                    .padding()
                HStack {
                    Text("Condition:")
                        .font(.headline)
                        .fontWeight(.bold)
                    /// This value changing is faked. In other words we just change it when the button is tapped. We have to fake it because we can't change text in the UI after the main thread is stalled.
                    Text("\(isTriggered ? "ANR" : "normal")")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(isTriggered ? .red : .primary)
                }
                Spacer()
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
