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

import OpenTelemetryApi
import SplunkAgent
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    // MARK: - Application lifecycle

    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.

        // Alternative deprecated Builder setup
        //        let builder = SplunkRumBuilder(
        //            realm: "realm",
        //            rumAuth: "token"
        //        )
        //            .setApplicationName("App Name")
        //            .deploymentEnvironment(environment: "dev")
        //            .debug(enabled: true)
        //            .sessionSamplingRatio(samplingRatio: 1)
        //            .showVCInstrumentation(true)
        //            .slowRenderingDetectionEnabled(true)
        //            .slowFrameDetectionThresholdMs(thresholdMs: 400)
        //            .frozenFrameDetectionThresholdMs(thresholdMs: 700)
        //            .globalAttributes(globalAttributes: ["isWorkingHard": true, "secret": "Red bull"])
        //            .ignoreURLs(ignoreURLs: try! NSRegularExpression(pattern: ".*\\.(jpg|jpeg|png|gif)$"))
        //            .networkInstrumentation(enabled: true)
        //            .build()

        let endpointConfig = EndpointConfiguration(
            realm: "realm",
            rumAccessToken: "token"
        )

        let agentConfig = AgentConfiguration(
            endpoint: endpointConfig,
            appName: "App Name",
            deploymentEnvironment: "dev"
        )
        .enableDebugLogging(true)
        .globalAttributes(
            MutableAttributes(dictionary: [
                "teststring": .string("value"),
                "testint": .int(100)
            ])
        )
        .spanInterceptor { spanData in
            var attributes = spanData.attributes
            attributes["test_attribute"] = AttributeValue("test_value")

            var modifiedSpan = spanData
            modifiedSpan.settingAttributes(attributes)

            return modifiedSpan
        }
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

    func application(
        _: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options _: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
