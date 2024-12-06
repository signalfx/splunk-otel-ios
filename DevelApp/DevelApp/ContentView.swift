//
//  ContentView.swift
//  DevelApp
//
//  Created by Pavel Kroh on 30.09.2023.
//

import SwiftUI
import CiscoRUM

struct ContentView: View {

    // MARK: - Versions

    let agentVersion = CiscoRUMAgent.version
    let agentAppVersion = CiscoRUMAgent.instance?.state.appVersion ?? "nil"


    // MARK: - Identifiers

    let userId = CiscoRUMAgent.instance?.user.identifier ?? "nil"
    @State private var sessionId = CiscoRUMAgent.instance?.session.currentSessionId ?? "nil"
    @State private var agentStatus = CiscoRUMAgent.instance?.state.status ?? .notRunning(.notEnabled)

    let sessionPublisher = NotificationCenter.default
        .publisher(
            for: NSNotification.Name("com.cisco.mrum.session-did-reset")
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
                
                Text("User ID: \(userId)")
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
                .sessionReplaySensitive()

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
