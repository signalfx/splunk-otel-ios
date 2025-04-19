//
//  ContentView.swift
//  DevelApp
//
//  Created by Pavel Kroh on 30.09.2023.
//

import SwiftUI
import SplunkAgent

struct ContentView: View {

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
        .onReceive(sessionPublisher) { (output) in
            if let currentSessionId = output.object as? String {
                withAnimation {
                    sessionId = currentSessionId
                }
            }
         }
    }
}

#Preview {
    ContentView()
}
