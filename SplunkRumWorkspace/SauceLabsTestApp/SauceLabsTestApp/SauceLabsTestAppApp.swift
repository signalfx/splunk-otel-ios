import SwiftUI
import SplunkOtel

@main
struct SauceLabsTestAppApp: App {
    init() {
        SplunkRum.initialize(
            beaconUrl: "http://127.0.0.1:8989/",
            rumAuth: "FAKE_RUM_AUTH",
            options: SplunkRumOptions(
                allowInsecureBeacon: true,
                debug: true,
                globalAttributes: [:]
            )
        )
    }
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView()
            }
        }
    }
}
