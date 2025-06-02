//
//  DevelAppApp.swift
//  DevelApp
//
//  Created by Pavel Kroh on 30.09.2023.
//

import SplunkAgent
import SwiftUI

@main
struct DevelAppApp: App {
    @StateObject var agent = initAgent()

    var body: some Scene {
        WindowGroup {
            RoutingView()
                .onAppear(perform: {
                    agent.sessionReplay.start()
                })
        }
    }

    private static func initAgent() -> SplunkRum {
        let agentConfig = AgentConfiguration(
            endpoint: .init(realm: "realm", rumAccessToken: "token"),
            appName: "App Name",
            deploymentEnvironment: "dev"
        )
            .enableDebugLogging(true)
            // Sampled-out agent
            //.sessionSamplingRate(0)
            .sessionSamplingRate(1)

        let agent = try! SplunkRum.install(with: agentConfig)

        return agent
    }
}
