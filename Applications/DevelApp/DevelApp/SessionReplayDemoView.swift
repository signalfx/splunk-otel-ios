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

//
//  SessionReplayDemoView.swift
//  DevelApp
//
//  Created by Pavel Kroh on 30.09.2023.
//

import SplunkAgent
import SwiftUI

struct SessionReplayDemoView: View {

    // MARK: - Versions

    let agentVersion = SplunkRum.version
    let agentAppVersion = SplunkRum.instance?.state.appVersion ?? "nil"


    // MARK: - Identifiers

    @State private var sessionId = SplunkRum.instance?.session.state.id ?? "nil"
    @State private var userTrackingMode = SplunkRum.instance?.user.state.trackingMode ?? .default
    @State private var agentStatus = SplunkRum.instance?.state.status ?? .notRunning(.notInstalled)

    let sessionPublisher = NotificationCenter.default
        .publisher(
            for: NSNotification.Name("com.splunk.rum.session-did-reset")
        )
        .receive(on: DispatchQueue.main)


    // MARK: - View

    @State var now = Date()

    let timer = Timer.publish(every: 0.2, on: .current, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Text("Agent Status:")
                Text("\(agentStatus)")
                    .padding(2)
                    .padding(.horizontal, 4)
                    .background(agentStatus == .running ? Color(.systemGreen) : Color(.systemRed))
                    .cornerRadius(4)
            }
            .padding(.vertical, 32)

            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)

            Text("Agent Version: \(agentVersion)")
            Text("Agent App Version: \(agentAppVersion)")

            VStack {
                Text("Session ID: \(sessionId)")
                    .transition(.opacity)
                    .id("LabelSessionID" + sessionId)

                Text("User Tracking: \(userTrackingMode)")
            }
            .foregroundColor(Color(uiColor: .black))
            .padding()
            .background(Color(.systemCyan).opacity(0.6))
            .cornerRadius(8)

            Text("\(now)")
                .onReceive(timer) { _ in
                    self.now = Date()
                }

            Text("Sensitive text")
//                .sessionReplaySensitive(true)

            Button {
                fatalError("Test fatal error from DevelApp.")
            } label: {
                Text("Crash")
            }

            Spacer()
        }
        .padding()
        .onReceive(sessionPublisher) { output in
            if let currentSessionId = output.object as? String {
                withAnimation {
                    sessionId = currentSessionId
                }
            }
         }
    }
}

#Preview {
    SessionReplayDemoView()
}
