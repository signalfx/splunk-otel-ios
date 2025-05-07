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

import SplunkAgent
import SplunkANRReporter
import SwiftUI

@main
struct ANRDemoApp: App {
    @StateObject var agent = initAgent()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private static func initAgent() -> SplunkRum {
        let agentConfig = AgentConfiguration(
            endpoint: .init(realm: "realm", rumAccessToken: "token"),
            appName: "App Name",
            deploymentEnvironment: "dev"
        )
            .enableDebugLogging(true)

        let agent = try! SplunkRum.install(with: agentConfig)

        return agent
    }
}
