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
        SplunkRum.initialize()
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
