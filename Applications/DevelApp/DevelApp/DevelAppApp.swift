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
    @StateObject var agent = SplunkRum.install(with:
        Configuration(url: vanityUrl())
            .appName("smartlook-ios")
            .appVersion("1.0.0")
    )

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear(perform: {
                    agent.sessionReplay.start()
                })
        }
    }

    private static func vanityUrl() -> URL {
        // Alameda
//        return URL(string: "https://alameda-eum-qe.saas.appd-test.com")!

        // smartlook c0 secondary
        return URL(string: "https://smartlookdev2.saas.appd-test.com")!

        // smartlook c0
//        return URL(string: "https://smartlookdev.saas.appd-test.com")!

        // Signoz
//        return URL(string: "https://otelcollector-http.us.smartlook.cloud")!
    }
}
