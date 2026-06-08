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
import UIKit

struct DemoHeaderView: View {

    @ObservedObject
    var agentDataSource = AgentDataSource()

    @State
    private var currentTime = Date()
    @State
    private var isSessionCopyButtonVisible = false
    @State
    private var isSessionCopied = false

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading) {
            Text("Agent Status: \(agentDataSource.agentStatusDescription)")
            Text("Agent Version: \(agentDataSource.agentVersion)")
            Text("Agent App Version: \(agentDataSource.agentAppVersion)")
            sessionIdRow
            HStack {
                Text("Current Time: \(currentTime, formatter: DateFormatter.shortTime)")
            }
            .onReceive(timer) { input in
                currentTime = input
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .frame(maxWidth: .infinity)
        .cornerRadius(8)
    }

    private var sessionIdRow: some View {
        Text("Session ID: \(agentDataSource.sessionId)")
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .accessibilityIdentifier("sessionIdLabel")
            .onTapGesture {
                isSessionCopied = false
                withAnimation(.easeInOut(duration: 0.15)) {
                    isSessionCopyButtonVisible = true
                }
            }
            .overlay(alignment: .trailing) {
                if isSessionCopyButtonVisible {
                    sessionCopyButton
                }
            }
    }

    private var sessionCopyButton: some View {
        Button(isSessionCopied ? "Copied" : "Copy") {
            UIPasteboard.general.string = agentDataSource.sessionId
            isSessionCopied = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSessionCopyButtonVisible = false
                }
                isSessionCopied = false
            }
        }
        .buttonStyle(.plain)
        .font(.caption.weight(.semibold))
        .frame(minWidth: 76)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isSessionCopied ? Color(.systemGray2) : Color(.systemGray3))
        .foregroundColor(.primary)
        .cornerRadius(6)
        .accessibilityIdentifier("copySessionIdButton")
        .zIndex(1)
        .transition(.opacity)
    }
}

extension DateFormatter {
    static let shortTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
