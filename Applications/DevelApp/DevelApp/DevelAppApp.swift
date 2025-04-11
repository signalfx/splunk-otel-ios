//
//  DevelAppApp.swift
//  DevelApp
//
//  Created by Pavel Kroh on 30.09.2023.
//

import SwiftUI
import SplunkAgent

@main
struct DevelAppApp: App {
    @StateObject var agent = initAgent()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear(perform: {
                    agent.sessionReplay.start()
                })
        }
    }

    private static func initAgent() -> SplunkRum {
        let agentConfig = try! AgentConfiguration(
            rumAccessToken: "token",
            endpoint: .init(realm: "realm"),
            appName: "App Name",
            deploymentEnvironment: "dev"
        )
            .enableDebugLogging(true)

        let agent = SplunkRum.install(with: agentConfig)

        return agent
    }
}
