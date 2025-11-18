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
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        let agentConfig = AgentConfiguration(
            endpoint: .init(realm: "realm", rumAccessToken: "token"),
            appName: "DevelApp",
            deploymentEnvironment: "dev"
        )
        .enableDebugLogging(true)
        .sessionConfiguration(SessionConfiguration(samplingRate: 1))

        do {
            _ = try SplunkRum.install(with: agentConfig)
        }
        catch {
            print("Unable to start the Splunk agent, error: \(error)")
        }

        // Navigation Instrumentation
        SplunkRum.shared.navigation.preferences.enableAutomatedTracking = true

        // Start session replay
        SplunkRum.shared.sessionReplay.start()

        // API to update Global Attributes
        SplunkRum.shared.globalAttributes.setBool(true, for: "isWorkingHard")
        SplunkRum.shared.globalAttributes[string: "secret"] = "Red bull"

        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(
        _: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options _: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_: UIApplication, didDiscardSceneSessions _: Set<UISceneSession>) {
        // Called when the user discards a scene session.
    }
}
