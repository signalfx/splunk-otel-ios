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

import SplunkAgent
import SwiftUI

struct SessionReplayDemoView: View {

    // MARK: - Versions

    let agentVersion = SplunkRum.version
    let agentAppVersion = SplunkRum.shared.state.appVersion


    // MARK: - Identifiers

    @State
    private var sessionId = SplunkRum.shared.session.state.id

    @State
    private var userTrackingMode = SplunkRum.shared.user.state.trackingMode

    @State
    private var agentStatus = SplunkRum.shared.state.status

    let sessionPublisher = NotificationCenter.default
        .publisher(
            for: NSNotification.Name("com.splunk.rum.session-did-reset")
        )
        .receive(on: DispatchQueue.main)


    // MARK: - View

    @State
    private var now = Date()

    let timer = Timer.publish(every: 0.2, on: .current, in: .common).autoconnect()

    // swiftlint:disable closure_body_length
    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Text("Agent Status:")
                Text(String(describing: agentStatus))
                    .padding(2)
                    .padding(.horizontal, 4)
                    .background(agentStatus == .running ? Color(.systemGreen) : Color(.systemRed))
                    .cornerRadius(4)
            }
            .padding(.vertical, 32)

            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)

            Text("Agent Version: \(agentVersion)")
            Text("Agent App Version: \(agentAppVersion)")

            VStack {
                Text("Session ID: \(String(describing: sessionId))")
                    .transition(.opacity)
                    .id("LabelSessionID" + sessionId)

                Text("User Tracking: \(String(describing: userTrackingMode))")
            }
            .foregroundColor(.black)
            .padding()
            .background(Color(UIColor.systemTeal).opacity(0.6))
            .cornerRadius(8)

            Text("\(now)")
                .onReceive(timer) { _ in
                    now = Date()
                }

            Text("Sensitive text")
            // .sessionReplaySensitive(true)

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
    // swiftlint:enable closure_body_length
}

struct SessionReplayDemoView_Previews: PreviewProvider {
    static var previews: some View {
        SessionReplayDemoView()
    }
}
