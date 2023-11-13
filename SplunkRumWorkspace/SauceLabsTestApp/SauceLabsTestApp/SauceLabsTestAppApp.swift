/*
Copyright 2023 Splunk Inc.

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

import SwiftUI
import SplunkOtel
import Swifter

var receivedSpans: [TestZipkinSpan] = []

struct TestZipkinSpan: Decodable {
    var name: String
    var tags: [String: String]
}

typealias SpanCallback = (TestZipkinSpan) -> Void

class PublishedState: ObservableObject {
    var listeners: [SpanCallback] = []

    func receiveSpans(spans: [TestZipkinSpan]) {
        DispatchQueue.main.async {
            for listener in self.listeners {
                for span in spans {
                    listener(span)
                }
            }
        }
    }

    func onSpan(_ on: @escaping SpanCallback) {
        self.listeners.append(on)
    }
}

var globalState = PublishedState()
let receiverUrl = "http://127.0.0.1:8989"

func receiverEndpoint(_ route: String) -> String {
    return "\(receiverUrl)\(route)"
}

@main
struct SauceLabsTestApp {
    static func main() {
        let server = HttpServer()

        server["/v1/traces"] = { request in
            let spans = try! JSONDecoder().decode([TestZipkinSpan].self, from: Data(request.body))
            receivedSpans.append(contentsOf: spans)
            globalState.receiveSpans(spans: spans)
            return HttpResponse.ok(.text("ok"))
        }

        server["/upload"] = { request in
            let body = String(decoding: Data(request.body), as: UTF8.self)
            return HttpResponse.ok(.text(body))
        }

        server["/"] = { _ in
            return HttpResponse.ok(.text("hello"))
        }

        try! server.start(8989)

        SplunkRumBuilder.init(
            beaconUrl: receiverEndpoint("/v1/traces"),
            rumAuth: "FAKE_RUM_AUTH"
        )
        .allowInsecureBeacon(enabled: true)
        .debug(enabled: true)
        .globalAttributes(globalAttributes: [:])
        .build()

        if #available(iOS 14.0, *) {
            TestApp.main()
        } else {
            UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(AppDelegate.self))
        }
    }
}

@available(iOS 14.0, *)
struct TestApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

class SceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if #unavailable(iOS 14.0) {
          let contentView = ContentView()

          if let windowScene = scene as? UIWindowScene {
              let window = UIWindow(windowScene: windowScene)
              window.rootViewController = UIHostingController(rootView: contentView)
              window.makeKeyAndVisible()
              self.window = window
          }
        }
    }
}
