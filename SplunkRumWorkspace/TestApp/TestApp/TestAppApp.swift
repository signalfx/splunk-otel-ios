//
//  TestAppApp.swift
//  TestApp
//
//  Created by jbley on 2/5/21.
//

import SwiftUI
import SplunkRum

@main
struct TestAppApp: App {
    init() {
        SplunkRum.initialize(beaconUrl: "http://127.0.0.1:9080/api/v2/spans", rumAuth: "FAKE_RUM_AUTH")
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
